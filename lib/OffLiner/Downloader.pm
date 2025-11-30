package OffLiner::Downloader;

use strict;
use warnings;
use 5.014;
use LWP::UserAgent;
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use Encode qw(decode encode);
use OffLiner::Parser qw(get_encoding extract_links);
use OffLiner::Utils qw(uri_to_path);
use OffLiner::Logger qw(log_error verbose);
use OffLiner::Stats qw(add_bytes);
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(create_user_agent fetch_url download_page);

# Crea un UserAgent configurato
sub create_user_agent {
    my ($user_agent, $timeout) = @_;
    $timeout //= 30;
    $user_agent //= 'Mozilla/5.0 (compatible; OffLinerBot/1.0)';
    
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 1);
    $ua->timeout($timeout);
    $ua->agent($user_agent);
    $ua->max_redirect(5);
    
    return $ua;
}

# Scarica un URL con retry
sub fetch_url {
    my ($url, $ua, $max_retries, $verbose) = @_;
    $max_retries //= 3;
    $verbose //= 0;
    
    my $response;
    my $retries = 0;
    my $last_status_code = 0;
    my $last_status_line = '';
    
    $ua ||= create_user_agent();
    
    while ($retries < $max_retries) {
        eval {
            $response = $ua->get($url);
        };
        
        if ($@) {
            $retries++;
            my $error_msg = "[!] Errore durante il download di $url: $@";
            warn "$error_msg\n" if $verbose;
            log_error($error_msg);
            sleep 2 if $retries < $max_retries;
            next;
        }
        
        if ($response && $response->is_success) {
            return $response;
        } else {
            # Estrai informazioni dettagliate sull'errore HTTP
            if ($response) {
                $last_status_code = $response->code;
                $last_status_line = $response->status_line;
                
                # Log dettagliato dell'errore HTTP
                my $status_msg = sprintf("[HTTP %d] %s - %s", 
                    $last_status_code, 
                    $last_status_line,
                    $url
                );
                
                if ($verbose) {
                    warn "[!] $status_msg - Tentativo $retries/$max_retries\n";
                }
                
                # Log sempre gli errori critici (5xx) e client (4xx)
                if ($last_status_code >= 400) {
                    log_error($status_msg);
                }
            } else {
                $last_status_line = 'No response received';
                if ($verbose) {
                    warn "[!] Nessuna risposta da $url - Tentativo $retries/$max_retries\n";
                }
                log_error("Nessuna risposta da $url");
            }
            
            $retries++;
            sleep 2 if $retries < $max_retries;
        }
    }
    
    # Log finale con dettagli completi
    my $final_error = sprintf("Impossibile scaricare %s dopo %d tentativi", $url, $max_retries);
    if ($last_status_code > 0) {
        $final_error .= sprintf(" - Ultimo errore: HTTP %d %s", $last_status_code, $last_status_line);
    }
    log_error($final_error);
    
    # IMPORTANTE: Ritorna la risposta anche se non è di successo, così download_page
    # può vedere il codice di errore HTTP e tracciarlo correttamente nelle statistiche
    # Se non c'è risposta, ritorna undef
    return $response;
}

# Scarica e salva una pagina
# Parametri opzionali alla fine: $bytes_batch_ref, $batch_size (per ottimizzazione batch)
sub download_page {
    my ($url, $depth, $ua, $output_dir, $max_depth, $max_retries, $visited, $visited_lock, $queue, $terminate, $pages_downloaded, $pages_failed, $pages_lock, $dir_cache, $verbose, $bytes_batch_ref, $batch_size) = @_;
    
    # Parametri opzionali per batch bytes (gestiti in modo sicuro)
    my $use_batch = defined $bytes_batch_ref && ref($bytes_batch_ref) eq 'SCALAR';
    $batch_size = 10000 unless defined $batch_size;
    
    return if $depth > $max_depth;
    return if $$terminate;
    
    # Ottimizzazione: check rapido locale prima del lock (per URL già processati)
    # Nota: questo è solo un hint, il lock è ancora necessario per thread-safety
    $visited_lock->down();
    if ($visited->{$url}) {
        $visited_lock->up();
        return;
    }
    $visited->{$url} = 1;
    $visited_lock->up();
    
    verbose("[+] Scaricamento [$depth]: $url\n");
    
    # Recupera il contenuto della pagina
    my $response = fetch_url($url, $ua, $max_retries, $verbose);
    
    # Gestisci errori HTTP: incrementa pages_failed per qualsiasi errore
    # (risposta non di successo o nessuna risposta)
    unless (defined $response && $response->is_success) {
        # Incrementa contatore errori e logga dettagli
        my $error_code = defined $response ? $response->code : 0;
        my $error_msg = defined $response ? $response->status_line : 'No response';
        
        if ($verbose) {
            my $status_info = $error_code > 0 
                ? sprintf("HTTP %d: %s", $error_code, $error_msg)
                : "Errore sconosciuto";
            verbose("[!] Fallito [$depth]: $url - $status_info\n");
        }
        
        # IMPORTANTE: Incrementa sempre pages_failed per errori HTTP
        # Questo assicura che gli errori HTTP vengano mostrati nelle statistiche
        $pages_lock->down();
        $$pages_failed++;
        $pages_lock->up();
        return;
    }
    
    # Determina il tipo di contenuto
    my $content_type = $response->header('Content-Type') || '';
    my $is_html = $content_type =~ /text\/html|application\/xhtml/i;
    
    # Ottimizzazione: traccia bytes con batch per ridurre lock contention
    my $content_length = 0;
    my $header_length = $response->header('Content-Length');
    if (defined $header_length && $header_length =~ /^\d+$/) {
        $content_length = int($header_length);
    } else {
        # Ottimizzazione: evita di caricare il contenuto se non necessario
        # Solo se dobbiamo scrivere il file, lo carichiamo
        # Per ora usiamo una stima basata su header se disponibile
        $content_length = 0;  # Sarà calcolato quando necessario
    }
    
    # Aggiorna batch bytes (se disponibile il riferimento)
    if ($use_batch && $content_length > 0) {
        $$bytes_batch_ref += $content_length;
        # Flush batch se raggiunge la dimensione massima
        if ($$bytes_batch_ref >= $batch_size) {
            eval {
                add_bytes($$bytes_batch_ref);
                $$bytes_batch_ref = 0;
            };
        }
    } elsif ($content_length > 0) {
        # Fallback: aggiorna direttamente se batch non disponibile
        eval {
            add_bytes($content_length);
        };
    }
    
    # Salvataggio della pagina
    my $path = uri_to_path($url, $is_html);
    my $full_path = File::Spec->catfile($output_dir, $path);
    
    # Verifica che la directory di destinazione esista (con cache)
    my $dir = dirname($full_path);
    unless ($dir_cache->{$dir} || -d $dir) {
        make_path($dir);
        $dir_cache->{$dir} = 1;
    }
    
    # Ottimizzazione: carica contenuto una sola volta e riutilizzalo
    my $content = $response->content;
    my $decoded_content;
    
    # Aggiorna content_length se non era disponibile dall'header
    if ($content_length == 0 && defined $content) {
        $content_length = length($content);
        # Aggiorna batch se necessario
        if ($use_batch && $content_length > 0) {
            $$bytes_batch_ref += $content_length;
            if ($$bytes_batch_ref >= $batch_size) {
                eval {
                    add_bytes($$bytes_batch_ref);
                    $$bytes_batch_ref = 0;
                };
            }
        } elsif ($content_length > 0) {
            eval {
                add_bytes($content_length);
            };
        }
    }
    
    # Scrivi il contenuto del file
    eval {
        if ($is_html) {
            my $encoding = get_encoding($response);
            $decoded_content = decode($encoding, $content);
            open my $fh, '>:encoding(UTF-8)', $full_path;
            print $fh $decoded_content;
            close $fh;
        } else {
            # Per file binari, scrivi direttamente
            open my $fh, '>', $full_path;
            binmode $fh;
            print $fh $content;
            close $fh;
        }
    };
    
    if ($@) {
        warn "[!] Errore durante il salvataggio di $url: $@\n" if $verbose;
        log_error("Errore salvataggio $url: $@");
        $pages_lock->down();
        $$pages_failed++;
        $pages_lock->up();
        return;
    }
    
    $pages_lock->down();
    $$pages_downloaded++;
    $pages_lock->up();
    
    # Ottimizzazione: analizza solo file HTML per trovare link
    # Riutilizza decoded_content già decodificato per evitare doppio parsing
    if ($is_html) {
        # Assicurati che decoded_content sia definito (fallback a content se necessario)
        my $content_for_links = $decoded_content;
        unless (defined $content_for_links) {
            # Fallback: usa il contenuto originale se decoded_content non è disponibile
            # Prova a decodificarlo se possibile
            if (defined $content) {
                eval {
                    my $encoding = get_encoding($response);
                    $content_for_links = decode($encoding, $content);
                };
                # Se la decodifica fallisce, usa il contenuto originale
                $content_for_links = $content unless defined $content_for_links;
            }
        }
        
        if (defined $content_for_links) {
            # Ottimizzazione: batch enqueue per ridurre lock contention
            my @new_links = ();
            
            extract_links($content_for_links, $url, sub {
                my ($abs_link) = @_;
                push @new_links, $abs_link;
            });
            
            # Enqueue tutti i link in un unico lock
            # IMPORTANTE: NON marcare come visitati qui - devono essere marcati solo quando scaricati
            if (@new_links && !$$terminate) {
                $visited_lock->down();
                for my $abs_link (@new_links) {
                    # Controlla se già visitato, ma NON marcare come visitato qui
                    # Il link verrà marcato come visitato quando verrà effettivamente scaricato
                    unless ($visited->{$abs_link}) {
                        # Aggiungi alla coda senza marcare come visitato
                        $queue->enqueue([$abs_link, $depth + 1]);
                    }
                }
                $visited_lock->up();
            }
        }
    }
}

1;

__END__

=encoding UTF-8

=head1 NAME

OffLiner::Downloader - Logica di download per OffLiner

=head1 SYNOPSIS

    use OffLiner::Downloader;

    my $ua = OffLiner::Downloader::create_user_agent($user_agent, $timeout);
    my $response = OffLiner::Downloader::fetch_url($url, $ua, $max_retries, $verbose);
    OffLiner::Downloader::download_page(...);

=head1 DESCRIPTION

Gestisce il download di pagine web, retry automatici e salvataggio dei file.

=head1 FUNCTIONS

=over 4

=item B<create_user_agent($user_agent, $timeout)>

Crea e configura un LWP::UserAgent.

=item B<fetch_url($url, $ua, $max_retries, $verbose)>

Scarica un URL con retry automatico.

=item B<download_page(...)>

Scarica e salva una pagina, estraendo i link per il crawling.

=back

=cut

