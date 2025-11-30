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
    
    $ua ||= create_user_agent();
    
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

# Scarica e salva una pagina
sub download_page {
    my ($url, $depth, $ua, $output_dir, $max_depth, $max_retries, $visited, $visited_lock, $queue, $terminate, $pages_downloaded, $pages_failed, $pages_lock, $dir_cache, $verbose) = @_;
    
    return if $depth > $max_depth;
    return if $$terminate;
    
    # Controlla se già visitato (thread-safe)
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
    unless ($response && $response->is_success) {
        $pages_lock->down();
        $$pages_failed++;
        $pages_lock->up();
        return;
    }
    
    # Determina il tipo di contenuto
    my $content_type = $response->header('Content-Type') || '';
    my $is_html = $content_type =~ /text\/html|application\/xhtml/i;
    
    # Traccia i bytes scaricati
    # Prova prima con Content-Length header (più accurato)
    my $content_length = 0;
    my $header_length = $response->header('Content-Length');
    if (defined $header_length && $header_length =~ /^\d+$/) {
        $content_length = int($header_length);
    }
    
    # Se non disponibile, usa la lunghezza del contenuto
    if ($content_length == 0) {
        my $content = $response->content;
        if (defined $content) {
            $content_length = length($content);
        }
    }
    
    # Traccia i bytes scaricati solo se abbiamo un valore valido
    if ($content_length > 0) {
        eval {
            add_bytes($content_length);
        };
        # Ignora errori nel tracciamento per non interrompere il download
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
        $$pages_failed++;
        $pages_lock->up();
        return;
    }
    
    $pages_lock->down();
    $$pages_downloaded++;
    $pages_lock->up();
    
    # Analizza solo file HTML per trovare link
    if ($is_html) {
        my $content = $response->decoded_content;
        
        extract_links($content, $url, sub {
            my ($abs_link) = @_;
            $visited_lock->down();
            unless ($visited->{$abs_link}) {
                $queue->enqueue([$abs_link, $depth + 1]) unless $$terminate;
            }
            $visited_lock->up();
        });
    }
}

1;

__END__

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

