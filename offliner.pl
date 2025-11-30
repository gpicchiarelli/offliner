#!/usr/bin/env perl

=head1 NAME

offliner - Scaricatore di siti web offline

=head1 VERSION

Version 1.0.0

=cut

use 5.010;
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

# Variabili di configurazione
my $url;
my $output_dir = "";
my $user_agent = DEFAULT_USER_AGENT;
my $max_depth = DEFAULT_MAX_DEPTH;
my $max_threads = DEFAULT_MAX_THREADS;
my $max_retries = DEFAULT_MAX_RETRIES;
my $verbose = 0;
my $help = 0;

# Parsing degli argomenti da riga di comando
GetOptions(
    'url=s'         => \$url,
    'user-agent=s'  => \$user_agent,
    'max-depth=i'   => \$max_depth,
    'max-threads=i' => \$max_threads,
    'output-dir=s'  => \$output_dir,
    'verbose|v'     => \$verbose,
    'help|h'        => \$help,
) or usage();

usage() if $help;
die "Devi specificare un URL con --url\n" unless $url;

# Valida URL
my $uri = URI->new($url);
unless ($uri->scheme && ($uri->scheme eq 'http' || $uri->scheme eq 'https')) {
    die "URL non valido. Deve essere http:// o https://\n";
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
my $empty_count = 0;
while (!$terminate) {
    sleep 1;
    if ($queue->pending() == 0) {
        $empty_count++;
        # Aspetta 3 secondi con coda vuota prima di terminare
        if ($empty_count >= 3) {
            last;
        }
    } else {
        $empty_count = 0;
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

sub usage {
    print <<"EOF";
Uso: $0 --url URL [opzioni]

Opzioni:
  --url URL              URL del sito da scaricare (obbligatorio)
  --output-dir DIR       Directory di output (default: directory corrente)
  --user-agent STRING    User-Agent personalizzato
  --max-depth N          Profondità massima dei link (default: 50)
  --max-threads N        Numero massimo di thread (default: 10)
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
    while (!$terminate) {
        my $job = $queue->dequeue();
        last if $job eq SENTINEL;
        
        my ($url, $depth) = @$job;
        download_page($url, $depth);
    }
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
    my ($url) = @_;
    my $response;
    my $retries = 0;
    
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 1);
    $ua->timeout(DEFAULT_TIMEOUT);
    $ua->agent($user_agent);
    $ua->max_redirect(5);

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
    my ($url, $depth) = @_;
    
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
    my $response = fetch_url($url);
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
    
    # Verifica che la directory di destinazione esista
    my $dir = dirname($full_path);
    unless (-d $dir) {
        make_path($dir);
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

Perl 5.10 o superiore e i seguenti moduli:

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

=item * Download parallelo multi-thread

=item * Thread-safe con semafori per la sincronizzazione

=item * Gestione errori con retry automatico

=item * Supporto HTTPS e SSL

=item * Rilevamento automatico della codifica

=item * Salvataggio intelligente dei file con struttura directory

=item * Log degli errori

=item * Terminazione pulita con gestione segnali

=item * Statistiche di download

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
