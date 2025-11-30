#!/usr/bin/env perl

=head1 NAME

offliner - Scaricatore di siti web offline

=head1 VERSION

Version 1.0.0

=cut

use 5.014;
use strict;
use warnings;
use utf8;
use autodie;

use FindBin qw($Bin);
use File::Path qw(make_path);
use File::Spec;
use File::Basename;
use Getopt::Long;
use Time::Piece;
use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;
use LWP::UserAgent;
use URI;
use Encode qw(decode encode);
use HTML::LinkExtor;
use HTML::HeadParser;
use IO::Socket::SSL;
use Mozilla::CA;
use JSON::PP qw(decode_json encode_json);

our $VERSION = '1.0.0';

$0 = "offliner";

# Costanti
use constant {
    DEFAULT_MAX_DEPTH   => 50,
    DEFAULT_MAX_THREADS => 10,
    DEFAULT_MAX_RETRIES => 3,
    DEFAULT_TIMEOUT     => 30,
    DEFAULT_USER_AGENT  => 'Mozilla/5.0 (compatible; OffLinerBot/1.0)',
    SENTINEL            => '__TERMINATE__',
};

# Lista dei moduli necessari
my @required_modules = qw(
    LWP::UserAgent
    URI
    File::Path
    File::Basename
    Getopt::Long
    Time::Piece
    threads
    Thread::Queue
    threads::shared
    Thread::Semaphore
    Encode
    HTML::LinkExtor
    HTML::HeadParser
    IO::Socket::SSL
    Mozilla::CA
    JSON::PP
);

# Verifica e installa moduli mancanti
sub check_and_install_modules {
    my @missing = ();
    
    foreach my $module (@required_modules) {
        eval "require $module";
        if ($@) {
            push @missing, $module;
        }
    }
    
    if (@missing) {
        print STDERR "[!] Moduli mancanti: " . join(', ', @missing) . "\n";
        print STDERR "[!] Installali con: cpanm " . join(' ', @missing) . "\n";
        print STDERR "[!] Oppure: cpan install " . join(' ', @missing) . "\n";
        exit 1;
    }
}

check_and_install_modules();

# Carica configurazione persistente (macOS)
my $config_file = $ENV{HOME} . '/.config/offliner/config.json';
my %config = load_config();

# Variabili di configurazione
my $url;
my $output_dir = "";
my $user_agent = DEFAULT_USER_AGENT;
my $max_depth = $config{default_max_depth} // DEFAULT_MAX_DEPTH;
my $max_threads = $config{default_max_threads} // DEFAULT_MAX_THREADS;
my $max_retries = $config{default_max_retries} // DEFAULT_MAX_RETRIES;
my $verbose = 0;
my $help = 0;
my $clipboard = 0;
my $check_update = 0;

# Parsing degli argomenti da riga di comando
GetOptions(
    'url=s'         => \$url,
    'user-agent=s'  => \$user_agent,
    'max-depth=i'   => \$max_depth,
    'max-threads=i' => \$max_threads,
    'max-retries=i' => \$max_retries,
    'output-dir=s'  => \$output_dir,
    'verbose|v'     => \$verbose,
    'help|h'        => \$help,
    'clipboard|c'   => \$clipboard,
    'check-update'   => \$check_update,
) or usage();

usage() if $help;

# Verifica aggiornamenti se richiesto
if ($check_update) {
    check_for_updates();
    exit 0;
}

# Supporto clipboard (macOS)
if ($clipboard && $^O eq 'darwin') {
    $url = get_clipboard_url();
    unless ($url) {
        die "Nessun URL trovato nella clipboard\n";
    }
    print "[+] URL dalla clipboard: $url\n" if $verbose;
}

die "Devi specificare un URL con --url o usare --clipboard\n" unless $url;

# Valida parametri
if ($max_depth < 0) {
    die "Errore: --max-depth deve essere >= 0\n";
}
if ($max_threads < 1) {
    die "Errore: --max-threads deve essere >= 1\n";
}
if ($max_retries < 1) {
    die "Errore: --max-retries deve essere >= 1\n";
}

# Valida URL
my $uri = URI->new($url);
unless ($uri->scheme && ($uri->scheme eq 'http' || $uri->scheme eq 'https')) {
    die "URL non valido. Deve essere http:// o https://\n";
}

# Usa directory di output dalla config se non specificata
if (!$output_dir && $config{default_output_dir}) {
    $output_dir = $config{default_output_dir};
}

# Ottieni il titolo del sito
my $title = get_site_title($url);
my $timestamp = localtime->strftime('%Y-%m-%d_%H-%M-%S');
my $base_output_dir = $output_dir || '.';
$output_dir = File::Spec->catfile($base_output_dir, sanitize_filename("${title}_${timestamp}"));

# Crea la directory di output
eval {
    make_path($output_dir) unless -d $output_dir;
};
if ($@) {
    die "Errore nella creazione della directory: $@\n";
}

# File di log nella directory di output
my $log_file = File::Spec->catfile($output_dir, 'download_log.txt');

# Hash condiviso per tracciare i link visitati (thread-safe)
my %visited :shared;

# Semaforo per proteggere l'accesso all'hash visited
my $visited_lock = Thread::Semaphore->new(1);

# Contatore condiviso per statistiche
my $pages_downloaded :shared = 0;
my $pages_failed :shared = 0;
my $pages_lock = Thread::Semaphore->new(1);

# Coda per i link da scaricare
my $queue = Thread::Queue->new();

# Flag per terminare i thread
my $terminate :shared = 0;

# Contatore thread attivi per monitoraggio efficiente
my $active_threads :shared = $max_threads;
my $threads_lock = Thread::Semaphore->new(1);

# Avvio dei thread
my @threads;
for (1..$max_threads) {
    push @threads, threads->create(\&worker_thread);
}

# Gestione segnali per terminazione pulita
$SIG{INT} = $SIG{TERM} = sub {
    print "\n[!] Interruzione ricevuta. Terminazione in corso...\n";
    $terminate = 1;
    # Invia sentinel a tutti i thread
    $queue->enqueue(SENTINEL) for 1..$max_threads;
};

# Aggiungi il primo URL alla coda
$queue->enqueue([$url, 0]);

# Monitora la coda e termina quando è vuota
# Usa un meccanismo più efficiente: aspetta che tutti i thread siano inattivi
# Attendi che la coda sia vuota e tutti i thread completati
my $empty_wait = 0;
while (!$terminate && $empty_wait < 5) {
    if ($queue->pending() == 0) {
        $threads_lock->down();
        my $active = $active_threads;
        $threads_lock->up();
        
        if ($active == 0) {
            $empty_wait++;
            # Aspetta 1 secondo per essere sicuri che non ci siano nuovi job
            sleep 1;
        } else {
            $empty_wait = 0;
            sleep 0.5;
        }
    } else {
        $empty_wait = 0;
        sleep 0.5;
    }
}

# Segnala terminazione ai thread
$terminate = 1;
$queue->enqueue(SENTINEL) for 1..$max_threads;

# Attendi che tutti i thread completino
$_->join() for @threads;

# Stampa statistiche finali
print "\n[+] Download completato.\n";
print "[+] Pagine scaricate: $pages_downloaded\n";
print "[+] Pagine fallite: $pages_failed\n";
print "[+] File salvati in: $output_dir\n";
print "[+] Log degli errori: $log_file\n";

# Notifica macOS se disponibile
if ($^O eq 'darwin' && !$terminate) {
    my $notify = $config{notifications_enabled} // 1;
    my $open_finder = $config{open_finder_on_complete} // 1;
    
    if ($notify) {
        if ($pages_failed > 0 && $pages_downloaded == 0) {
            # Tutto fallito
            send_macos_notification(
                "Download fallito",
                "Impossibile scaricare il sito.\nPagine fallite: $pages_failed",
                undef,
                0
            );
        } elsif ($pages_failed > 0) {
            # Parziale
            send_macos_notification(
                "Download completato con errori",
                "Pagine scaricate: $pages_downloaded\nPagine fallite: $pages_failed",
                $open_finder ? $output_dir : undef,
                0
            );
        } else {
            # Successo
            send_macos_notification(
                "Download completato",
                "Pagine scaricate: $pages_downloaded\nPagine fallite: $pages_failed",
                $open_finder ? $output_dir : undef,
                1
            );
        }
    }
}

sub usage {
    print <<"EOF";
Uso: $0 --url URL [opzioni]

Opzioni:
  --url URL              URL del sito da scaricare (obbligatorio, tranne con --clipboard)
  --output-dir DIR       Directory di output (default: dalla configurazione o directory corrente)
  --user-agent STRING    User-Agent personalizzato
  --max-depth N          Profondità massima dei link (default: dalla configurazione o 50)
  --max-threads N        Numero massimo di thread (default: dalla configurazione o 10)
  --max-retries N        Numero massimo di tentativi per URL (default: dalla configurazione o 3)
  --clipboard, -c         Usa URL dalla clipboard (macOS)
  --check-update          Verifica se ci sono aggiornamenti disponibili
  --verbose, -v          Output verboso
  --help, -h             Mostra questo messaggio

Esempi:
  $0 --url https://example.com
  $0 --url https://example.com --max-depth 10 --max-threads 5
  $0 --url https://example.com --output-dir /tmp/downloads --verbose

EOF
    exit 0;
}

# Funzione per il thread worker
sub worker_thread {
    # Crea un LWP::UserAgent per thread (riutilizzabile)
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 1);
    $ua->timeout(DEFAULT_TIMEOUT);
    $ua->agent($user_agent);
    $ua->max_redirect(5);
    
    # Cache per directory già create (per thread)
    my %dir_cache;
    
    while (!$terminate) {
        # Usa dequeue_timed per evitare busy waiting
        my $job = $queue->dequeue_timed(1);
        if (!defined $job) {
            # Timeout - thread inattivo
            $threads_lock->down();
            $active_threads--;
            $threads_lock->up();
            
            # Aspetta un po' prima di riprovare
            sleep 0.1;
            
            $threads_lock->down();
            $active_threads++;
            $threads_lock->up();
            next;
        }
        
        last if $job eq SENTINEL;
        
        $threads_lock->down();
        $active_threads--;
        $threads_lock->up();
        
        my ($url, $depth) = @$job;
        download_page($url, $depth, $ua, \%dir_cache);
        
        $threads_lock->down();
        $active_threads++;
        $threads_lock->up();
    }
    
    # Thread terminato
    $threads_lock->down();
    $active_threads--;
    $threads_lock->up();
}

# Funzione per ottenere il titolo del sito
sub get_site_title {
    my ($url) = @_;
    my $uri = URI->new($url);
    my $host = $uri->host || 'unknown';
    $host =~ s/^www\.//;
    return $host;
}

# Funzione per effettuare il download di un URL con retry
sub fetch_url {
    my ($url, $ua) = @_;
    my $response;
    my $retries = 0;
    
    # Usa LWP::UserAgent passato come parametro (riutilizzabile)
    $ua ||= do {
        my $new_ua = LWP::UserAgent->new;
        $new_ua->ssl_opts(verify_hostname => 1);
        $new_ua->timeout(DEFAULT_TIMEOUT);
        $new_ua->agent($user_agent);
        $new_ua->max_redirect(5);
        $new_ua;
    };

    while ($retries < $max_retries) {
        eval {
            $response = $ua->get($url);
        };
        
        if ($@) {
            $retries++;
            warn "[!] Errore durante il download di $url: $@\n" if $verbose;
            sleep 2 if $retries < $max_retries;
            next;
        }
        
        if ($response && $response->is_success) {
            return $response;
        } else {
            $retries++;
            if ($verbose) {
                my $status = $response ? $response->status_line : 'Unknown error';
                warn "[!] Errore scaricamento $url: $status - Tentativo $retries/$max_retries\n";
            }
            sleep 2 if $retries < $max_retries;
        }
    }

    log_error("Impossibile scaricare $url dopo $max_retries tentativi.");
    return undef;
}

# Funzione per determinare la codifica
sub get_encoding {
    my ($response) = @_;
    
    # Prova a ottenere la codifica dall'header Content-Type
    my $content_type = $response->header('Content-Type');
    if ($content_type && $content_type =~ /charset=([^\s;]+)/i) {
        return $1;
    }
    
    # Prova a parsare l'HTML per trovare la codifica
    my $parser = HTML::HeadParser->new;
    eval {
        $parser->parse($response->content);
        my $meta_content_type = $parser->header('Content-Type');
        if ($meta_content_type && $meta_content_type =~ /charset=([^\s;]+)/i) {
            return $1;
        }
    };
    
    # Default a UTF-8 se non trovato
    return 'UTF-8';
}

# Funzione per scaricare e analizzare una pagina
sub download_page {
    my ($url, $depth, $ua, $dir_cache) = @_;
    
    return if $depth > $max_depth;
    return if $terminate;
    
    # Controlla se già visitato (thread-safe)
    $visited_lock->down();
    if ($visited{$url}) {
        $visited_lock->up();
        return;
    }
    $visited{$url} = 1;
    $visited_lock->up();
    
    print "[+] Scaricamento [$depth]: $url\n" if $verbose;
    
    # Recupera il contenuto della pagina
    my $response = fetch_url($url, $ua);
    unless ($response && $response->is_success) {
        $pages_lock->down();
        $pages_failed++;
        $pages_lock->up();
        return;
    }
    
    # Determina il tipo di contenuto
    my $content_type = $response->header('Content-Type') || '';
    my $is_html = $content_type =~ /text\/html|application\/xhtml/i;
    
    # Salvataggio della pagina
    my $path = uri_to_path($url, $is_html);
    my $full_path = File::Spec->catfile($output_dir, $path);
    
    # Verifica che la directory di destinazione esista (con cache)
    my $dir = dirname($full_path);
    unless ($dir_cache->{$dir} || -d $dir) {
        make_path($dir);
        $dir_cache->{$dir} = 1;
    }
    
    # Scrivi il contenuto del file
    eval {
        if ($is_html) {
            my $encoding = get_encoding($response);
            my $content = decode($encoding, $response->content);
            open my $fh, '>:encoding(UTF-8)', $full_path;
            print $fh $content;
            close $fh;
        } else {
            # Per file binari, scrivi direttamente
            open my $fh, '>', $full_path;
            binmode $fh;
            print $fh $response->content;
            close $fh;
        }
    };
    
    if ($@) {
        warn "[!] Errore durante il salvataggio di $url: $@\n" if $verbose;
        log_error("Errore salvataggio $url: $@");
        $pages_lock->down();
        $pages_failed++;
        $pages_lock->up();
        return;
    }
    
    $pages_lock->down();
    $pages_downloaded++;
    $pages_lock->up();
    
    # Analizza solo file HTML per trovare link
    if ($is_html) {
        my $content = $response->decoded_content;
        my $base_uri = URI->new($url);
        
        my $parser = HTML::LinkExtor->new(sub {
            my ($tag, %attr) = @_;
            
            # Lista di tag da controllare
            return unless $tag =~ /^(a|img|link|script|iframe|video|audio|source|object|embed|meta|track|form)$/;
            
            # Estrazione link dai vari attributi
            my $link = $attr{href} || $attr{src} || $attr{data} || 
                       $attr{action} || $attr{poster} || 
                       ($tag eq 'meta' ? $attr{content} : undef);
            
            return unless $link;
            
            # Gestione di meta-refresh
            if ($tag eq 'meta' && $link =~ /URL=([^;]+)/i) {
                $link = $1;
            }
            
            # Converti in URL assoluto
            my $abs_link;
            eval {
                $abs_link = URI->new_abs($link, $base_uri)->as_string;
            };
            return unless $abs_link;
            
            # Aggiungi alla coda solo link validi HTTP/HTTPS dello stesso dominio
            if ($abs_link =~ /^https?:\/\//) {
                my $link_uri = URI->new($abs_link);
                # Segui solo link dello stesso dominio (opzionale: rimuovi per seguire tutti i link)
                if ($link_uri->host && $link_uri->host eq $base_uri->host) {
                    $visited_lock->down();
                    unless ($visited{$abs_link}) {
                        $queue->enqueue([$abs_link, $depth + 1]) unless $terminate;
                    }
                    $visited_lock->up();
                }
            }
        });
        
        eval {
            $parser->parse($content);
        };
        if ($@ && $verbose) {
            warn "[!] Errore parsing HTML per $url: $@\n";
        }
    }
}

# Funzione per registrare gli errori nel file di log
sub log_error {
    my ($message) = @_;
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    eval {
        open my $log_fh, '>>:encoding(UTF-8)', $log_file;
        print $log_fh "[$timestamp] $message\n";
        close $log_fh;
    };
    # Ignora errori di scrittura del log per non interrompere l'esecuzione
}

# Converte l'URL in un percorso di file
sub uri_to_path {
    my ($uri, $is_html) = @_;
    
    my $u = URI->new($uri);
    my $path = $u->path || '/';
    $path =~ s{^/}{};
    $path =~ s{/$}{/index} if $path;
    $path ||= 'index';
    
    # Rimuovi caratteri problematici
    $path =~ s/[^\w\.\-\/]/_/g;
    $path =~ s{/+}{/}g;
    
    # Aggiungi estensione se necessario
    unless ($path =~ /\.[a-z]{2,4}$/i) {
        $path .= $is_html ? '.html' : '';
    }
    
    return $path;
}

# Funzione per sanificare il nome della directory
sub sanitize_filename {
    my ($filename) = @_;
    $filename =~ s/[^a-zA-Z0-9._-]/_/g;
    $filename =~ s/_+/_/g;
    $filename =~ s/^_|_$//g;
    return $filename || 'download';
}

# Funzione per inviare notifiche macOS
sub send_macos_notification {
    my ($title, $message, $output_path, $success) = @_;
    $success = 1 unless defined $success;
    
    return unless $^O eq 'darwin';
    return unless -x '/usr/bin/osascript';
    
    # Escape caratteri speciali per AppleScript (metodo robusto)
    $title =~ s/\\/\\\\/g;
    $title =~ s/"/\\"/g;
    $title =~ s/\$/\\\$/g;
    $title =~ s/`/\\`/g;
    
    $message =~ s/\\/\\\\/g;
    $message =~ s/"/\\"/g;
    $message =~ s/\$/\\\$/g;
    $message =~ s/`/\\`/g;
    $message =~ s/\n/\\n/g;
    
    my $sound = $success ? 'Glass' : 'Basso';
    
    # Usa AppleScript con escape corretto
    my $script = qq{display notification "$message" with title "$title" subtitle "OffLiner" sound name "$sound"};
    
    eval {
        open my $pipe, '|-', 'osascript', '-e', $script or return;
        close $pipe;
    };
    
    # Apri Finder nella directory di output (opzionale)
    if ($output_path && -d $output_path && -x '/usr/bin/open') {
        eval {
            system('open', $output_path) == 0;
        };
    }
}

# Funzione per caricare configurazione
sub load_config {
    my %config = ();
    
    if (-f $config_file && -r $config_file) {
        eval {
            open my $fh, '<', $config_file or die "Cannot read config: $!";
            local $/;
            my $json = <$fh>;
            close $fh;
            my $data = decode_json($json);
            %config = %$data;
        };
        if ($@ && $verbose) {
            warn "[!] Errore lettura config: $@\n";
        }
    }
    
    return %config;
}

# Funzione per ottenere URL dalla clipboard (macOS)
sub get_clipboard_url {
    return undef unless $^O eq 'darwin';
    return undef unless -x '/usr/bin/pbpaste';
    
    my $clipboard = `pbpaste 2>/dev/null`;
    chomp $clipboard;
    
    # Cerca URL nel testo
    if ($clipboard =~ /(https?:\/\/[^\s]+)/) {
        return $1;
    }
    
    # Se è già un URL valido
    if ($clipboard =~ /^https?:\/\//) {
        return $clipboard;
    }
    
    return undef;
}

# Funzione per verificare aggiornamenti
sub check_for_updates {
    my $current_version = $VERSION;
    
    eval {
        require LWP::UserAgent;
        my $ua = LWP::UserAgent->new(timeout => 5);
        $ua->agent("OffLiner/$VERSION");
        
        my $response = $ua->get('https://api.github.com/repos/gpicchiarelli/offliner/releases/latest');
        
        if ($response->is_success) {
            my $content = $response->decoded_content;
            if ($content =~ /"tag_name"\s*:\s*"v?([\d.]+)"/) {
                my $latest_version = $1;
                if (version_compare($latest_version, $current_version) > 0) {
                    print "📦 Nuova versione disponibile: $latest_version (attuale: $current_version)\n";
                    print "Scarica da: https://github.com/gpicchiarelli/offliner/releases/latest\n";
                } else {
                    print "✓ Sei aggiornato alla versione $current_version\n";
                }
            }
        }
    };
    
    if ($@) {
        warn "Impossibile verificare aggiornamenti: $@\n" if $verbose;
    }
}

# Funzione per confrontare versioni
sub version_compare {
    my ($v1, $v2) = @_;
    my @v1_parts = split /\./, $v1;
    my @v2_parts = split /\./, $v2;
    
    for my $i (0..$#v1_parts) {
        my $p1 = $v1_parts[$i] || 0;
        my $p2 = $v2_parts[$i] || 0;
        return 1 if $p1 > $p2;
        return -1 if $p1 < $p2;
    }
    
    return 0;
}

__END__

=head1 SYNOPSIS

    perl offliner.pl --url https://example.com [opzioni]

=head1 DESCRIPTION

OffLiner è un'utility Perl per scaricare siti web e navigarli offline, 
mantenendo la struttura e i link. Supporta download parallelo con 
multi-threading, gestione degli errori con retry automatico, e 
salvataggio intelligente dei file.

=head1 OPTIONS

=over 8

=item B<--url URL>

URL del sito da scaricare. Questo parametro è obbligatorio.
Deve essere un URL valido con schema http:// o https://.

=item B<--output-dir DIR>

Directory di output dove salvare i file scaricati. 
Se non specificata, usa la directory corrente.

=item B<--user-agent STRING>

User-Agent personalizzato da usare durante il download. 
Default: 'Mozilla/5.0 (compatible; OffLinerBot/1.0)'.

=item B<--max-depth N>

Profondità massima di link da seguire. Default: 50.

=item B<--max-threads N>

Numero massimo di thread per il download parallelo. Default: 10.

=item B<--verbose, -v>

Abilita output verboso con informazioni di debug.

=item B<--help, -h>

Mostra il messaggio di aiuto e esce.

=back

=head1 EXAMPLES

    # Download base
    perl offliner.pl --url https://example.com

    # Download con opzioni personalizzate
    perl offliner.pl --url https://example.com --max-depth 10 --max-threads 5

    # Download con output verboso
    perl offliner.pl --url https://example.com --output-dir /tmp/downloads --verbose

=head1 REQUIREMENTS

Perl 5.14 o superiore e i seguenti moduli:

=over 4

=item * LWP::UserAgent

=item * URI

=item * File::Path

=item * File::Basename

=item * Getopt::Long

=item * Time::Piece

=item * threads

=item * Thread::Queue

=item * threads::shared

=item * Thread::Semaphore

=item * Encode

=item * HTML::LinkExtor

=item * HTML::HeadParser

=item * IO::Socket::SSL

=item * Mozilla::CA

=back

I moduli possono essere installati con:

    cpanm --installdeps .

oppure manualmente con:

    cpan install LWP::UserAgent URI File::Path ...

=head1 FEATURES

=over 4

=item * Download parallelo multi-thread ottimizzato

=item * Thread-safe con semafori per la sincronizzazione

=item * Gestione errori con retry automatico configurabile

=item * Supporto HTTPS e SSL

=item * Rilevamento automatico della codifica

=item * Salvataggio intelligente dei file con struttura directory

=item * Log degli errori con timestamp

=item * Terminazione pulita con gestione segnali

=item * Statistiche di download in tempo reale

=item * Riutilizzo LWP::UserAgent per migliori performance

=item * Cache directory per ridurre chiamate filesystem

=item * Monitoraggio efficiente thread con dequeue_timed

=back

=head1 AUTHOR

Giacomo Picchiarelli

=head1 LICENSE

BSD 3-Clause License

Copyright (c) 2024, Giacomo Picchiarelli

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
