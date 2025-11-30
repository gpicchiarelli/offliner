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
use lib "$FindBin::Bin/lib", "$FindBin::Bin";
use File::Path qw(make_path);
use File::Spec;
use Getopt::Long;
use Time::Piece;
use Time::HiRes qw(time);
use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

# Moduli OffLiner
use OffLiner::Config qw(load_config validate_params);
use OffLiner::Utils qw(get_site_title sanitize_filename validate_url);
use OffLiner::Logger qw(init log_error verbose info);
use OffLiner::Platform::macOS qw(get_clipboard_url send_notification);
use OffLiner::Version qw(check_for_updates);
use OffLiner::Worker qw(worker_thread);
use OffLiner::Stats qw(init_stats update_stats display_stats format_time get_elapsed_time);

our $VERSION = '1.0.0';

$0 = "offliner";

# Costante sentinel
use constant SENTINEL => '__TERMINATE__';

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

# Carica configurazione persistente
my %config = load_config();

# Variabili di configurazione
my $url;
my $output_dir = "";
my $user_agent = OffLiner::Config::DEFAULT_USER_AGENT();
my $max_depth = $config{default_max_depth} // OffLiner::Config::DEFAULT_MAX_DEPTH();
my $max_threads = $config{default_max_threads} // OffLiner::Config::DEFAULT_MAX_THREADS();
my $max_retries = $config{default_max_retries} // OffLiner::Config::DEFAULT_MAX_RETRIES();
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
    check_for_updates($VERSION, $verbose);
    exit 0;
}

# Supporto clipboard (macOS)
if ($clipboard) {
    $url = get_clipboard_url();
    unless ($url) {
        die "Nessun URL trovato nella clipboard\n";
    }
    verbose("[+] URL dalla clipboard: $url\n");
}

die "Devi specificare un URL con --url o usare --clipboard\n" unless $url;

# Valida parametri
validate_params(
    max_depth => $max_depth,
    max_threads => $max_threads,
    max_retries => $max_retries
);

# Valida URL
unless (validate_url($url)) {
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

# Inizializza logger
init($log_file, $verbose);

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
    push @threads, threads->create(\&OffLiner::Worker::worker_thread, {
        user_agent => $user_agent,
        max_retries => $max_retries,
        max_depth => $max_depth,
        output_dir => $output_dir,
        queue => $queue,
        visited => \%visited,
        visited_lock => $visited_lock,
        pages_downloaded => \$pages_downloaded,
        pages_failed => \$pages_failed,
        pages_lock => $pages_lock,
        terminate => \$terminate,
        active_threads => \$active_threads,
        threads_lock => $threads_lock,
        verbose => $verbose,
        SENTINEL => SENTINEL,
    });
}

# Gestione segnali per terminazione pulita
$SIG{INT} = $SIG{TERM} = sub {
    info("\n[!] Interruzione ricevuta. Terminazione in corso...\n");
    $terminate = 1;
    # Invia sentinel a tutti i thread
    $queue->enqueue(SENTINEL) for 1..$max_threads;
};

# Inizializza statistiche
init_stats();

# Variabili per colori (dichiarate una sola volta) - schema scuro e adattabile
my $RESET = "\033[0m";
my $BOLD = "\033[1m";
my $CYAN = "\033[38;5;30m";    # Ciano scuro
my $GREEN = "\033[38;5;34m";   # Verde scuro

# Messaggio iniziale
binmode STDOUT, ':utf8'; # Gestisce correttamente i caratteri Unicode
print "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}\n";
print "${CYAN}${BOLD}  OffLiner - Avvio download${RESET}\n";
print "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}\n";
print "${CYAN}[URL]${RESET} $url\n";
print "${CYAN}[OUTPUT]${RESET} $output_dir\n";
print "${CYAN}[THREADS]${RESET} $max_threads  ${CYAN}[DEPTH]${RESET} $max_depth\n";
print "${CYAN}[AGENT]${RESET} $user_agent\n";
print "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}\n\n";

# Aggiungi il primo URL alla coda
$queue->enqueue([$url, 0]);

# Ottimizzazione: loop principale più efficiente con meno lock e sleep intelligente
my $empty_wait = 0;
my $last_stats_update = 0;
my $STATS_UPDATE_INTERVAL = 0.5;  # Aggiorna stats ogni 0.5s
my $IDLE_SLEEP = 0.1;  # Sleep quando c'è lavoro (ridotto per essere più reattivi)
my $EMPTY_SLEEP = 0.3;  # Sleep quando coda vuota (ridotto per terminare più velocemente)
my $MAX_EMPTY_WAIT = 3;  # Ridotto da 5 a 3 per terminare più velocemente

while (!$terminate && $empty_wait < $MAX_EMPTY_WAIT) {
    my $current_time = time();
    my $queue_size = $queue->pending();
    
    # Ottimizzazione: aggiorna stats solo quando necessario
    if ($current_time - $last_stats_update >= $STATS_UPDATE_INTERVAL) {
        # Raggruppa tutti i lock in sequenza per ridurre overhead
        $threads_lock->down();
        my $active = $active_threads;
        $threads_lock->up();
        
        $pages_lock->down();
        my $downloaded = $pages_downloaded;
        my $failed = $pages_failed;
        $pages_lock->up();
        
        $visited_lock->down();
        my $visited_count = scalar keys %visited;
        $visited_lock->up();
        
        my $stats = update_stats(
            $downloaded,
            $failed,
            $queue_size,
            $active,
            $visited_count
        );
        $stats->{max_threads} = $max_threads;
        
        display_stats($stats);
        $last_stats_update = $current_time;
    }
    
    # Ottimizzazione: logica di attesa più efficiente
    if ($queue_size == 0) {
        $threads_lock->down();
        my $active = $active_threads;
        $threads_lock->up();
        
        if ($active == 0) {
            $empty_wait++;
            # Aspetta un po' per essere sicuri che non ci siano nuovi job in arrivo
            sleep $EMPTY_SLEEP;  # Sleep più lungo quando tutto è vuoto
        } else {
            $empty_wait = 0;  # Reset se ci sono thread attivi
            sleep $IDLE_SLEEP;  # Sleep breve se ci sono thread attivi
        }
    } else {
        $empty_wait = 0;  # Reset se c'è lavoro nella coda
        # Sleep breve quando c'è lavoro da fare per essere più reattivi
        sleep $IDLE_SLEEP;
    }
}

# Segnala terminazione ai thread
$terminate = 1;
# Invia sentinel a tutti i thread per assicurarsi che terminino
# Invia più sentinel per essere sicuri che tutti i thread li ricevano
$queue->enqueue(SENTINEL) for 1..($max_threads * 2);

# Attendi che tutti i thread completino
foreach my $thread (@threads) {
    eval {
        $thread->join();
    };
    if ($@) {
        warn "Errore nel join del thread: $@\n" if $verbose;
    }
}

# Pulisci l'ultima visualizzazione e mostra statistiche finali
print "\n";

$pages_lock->down();
my $final_downloaded = $pages_downloaded;
my $final_failed = $pages_failed;
$pages_lock->up();

$visited_lock->down();
my $final_visited = scalar keys %visited;
$visited_lock->up();

# Calcola tempo totale
my $total_elapsed = get_elapsed_time();

# Crea statistiche finali
my $final_stats = {
    elapsed => $total_elapsed,
    pages_downloaded => $final_downloaded,
    pages_failed => $final_failed,
    queue_size => 0,
    active_threads => 0,
    visited_count => $final_visited,
    rate => $total_elapsed > 0 ? $final_downloaded / $total_elapsed : 0,
    total => $final_downloaded + $final_failed,
    max_threads => $max_threads,
};

# Mostra statistiche finali
display_stats($final_stats);

# Messaggio di completamento (riusa le variabili già dichiarate)
print "\n${GREEN}${BOLD}[SUCCESS]${RESET} Download completato con successo!\n";
print "${CYAN}[INFO]${RESET} File salvati in: ${BOLD}$output_dir${RESET}\n";
print "${CYAN}[INFO]${RESET} Log degli errori: ${BOLD}$log_file${RESET}\n";

# Notifica macOS se disponibile
if ($^O eq 'darwin' && !$terminate) {
    my $notify = $config{notifications_enabled} // 1;
    my $open_finder = $config{open_finder_on_complete} // 1;
    
    if ($notify) {
        if ($pages_failed > 0 && $pages_downloaded == 0) {
            # Tutto fallito
            send_notification(
                "Download fallito",
                "Impossibile scaricare il sito.\nPagine fallite: $pages_failed",
                undef,
                0
            );
        } elsif ($pages_failed > 0) {
            # Parziale
            send_notification(
                "Download completato con errori",
                "Pagine scaricate: $pages_downloaded\nPagine fallite: $pages_failed",
                $open_finder ? $output_dir : undef,
                0
            );
        } else {
            # Successo
            send_notification(
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

__END__

=encoding UTF-8

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
