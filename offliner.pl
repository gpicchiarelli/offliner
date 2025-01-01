#!/usr/bin/env perl

use strict;
use warnings;
use File::Path qw(make_path);
use HTTP::Tiny;
use HTML::LinkExtor;
use LWP::UserAgent;
use URI;
use File::Basename;
use Getopt::Long;
use Time::Piece;
use threads;
use Thread::Queue;
use IO::Socket::SSL;  # Necessario per supporto HTTPS
use Mozilla::CA;
use Encode qw(decode encode);
use HTML::HeadParser;

$0 = "offliner";

# Lista dei moduli necessari
my @modules = qw(
    HTTP::Tiny
    HTML::LinkExtor
    URI
    File::Path
    File::Basename
    Getopt::Long
    LWP::UserAgent
    IO::Socket::SSL
    Mozilla::CA
);

# Funzione per installare i moduli mancanti
sub install_module {
    my ($module) = @_;
    
    eval "use $module";
    if ($@) {
        print "[+] Modulo $module non trovato. Tentativo di installazione...\n";
        system("cpan $module") == 0 or die "[-] Errore durante l'installazione di $module. Verifica i permessi o la connessione internet.\n";
        eval "use $module";
        if ($@) {
            die "[-] Impossibile installare il modulo $module. Assicurati di avere accesso a internet e permessi di scrittura.\n";
        }
    }
}

# Installazione automatica dei moduli richiesti
foreach my $module (@modules) {
    install_module($module);
}

# Variabili di configurazione
my $url;
my $output_dir;
my $user_agent = 'Mozilla/5.0 (compatible; OffLinerBot/1.0)';
my $max_depth = 50;
my $max_threads = 10;  # Limita il numero di thread
my $max_retries = 3;   # Numero massimo di tentativi per ogni richiesta HTTP

# File di log per registrare gli errori
my $log_file = 'download_log.txt';

# Parsing degli argomenti da riga di comando
GetOptions(
    'url=s'         => \$url,
    'user-agent=s'  => \$user_agent,
    'max-depth=i'   => \$max_depth,
    'max-threads=i' => \$max_threads,
) or die "Uso: $0 --url URL [--max-depth N] [--max-threads N]\n";

die "Devi specificare un URL con --url\n" unless $url;

# Ottieni il titolo del sito
my $title = get_site_title($url);
my $timestamp = localtime->strftime('%Y-%m-%d_%H-%M-%S');
$output_dir = sanitize_filename("${title}_${timestamp}");

# Crea la directory di output
make_path($output_dir) unless -d $output_dir;

# Hash per tracciare i link visitati
my %visited;

# Coda per i link da scaricare
my $queue = Thread::Queue->new();

# Avvio dei thread
my @threads;
for (1..$max_threads) {
    push @threads, threads->create(\&worker_thread);
}

# Aggiungi il primo URL alla coda
$queue->enqueue([$url, 0]);

# Funzione per il thread worker
sub worker_thread {
    while (my $job = $queue->dequeue()) {
        my ($url, $depth) = @$job;
        download_page($url, $depth);
    }
}

# Funzione per ottenere il titolo del sito
sub get_site_title {
        my ($url) = @_;
        my $uri = URI->new($url);
        return $uri->host;
}

# Funzione per effettuare il download di un URL con retry in caso di errori
sub fetch_url {
    my ($url) = @_;
    my $response;
    my $retries = 0;
    
    # Inizializzazione corretta di $ua
    my $ua = LWP::UserAgent->new;
    $ua->ssl_opts(verify_hostname => 1);  # Verifica del nome host (opzionale)
    $ua->timeout(10);
    $ua->agent($user_agent);  # Impostazione dell'user-agent

    while ($retries < $max_retries) {
        binmode STDOUT, ':encoding(UTF-8)';
        print "[DEBUG] Tentativo di scaricare $url\n";  # Debug per tracciare i tentativi

        $response = $ua->get($url);  # Tentativo di scaricare il contenuto
        if ($response->is_success) {
            binmode STDOUT, ':encoding(UTF-8)';
            print "[DEBUG] Scaricato con successo: $url\n";  # Debug per tracciare i successi
            return $response;
        } else {
            $retries++;
            binmode STDOUT, ':encoding(UTF-8)';
            print "[DEBUG] Errore scaricamento $url: " . $response->status_line . " - Tentativo $retries/$max_retries\n";  # Debug per tracciare gli errori
            sleep 2;  # Pausa tra i tentativi
        }
    }

    log_error("Impossibile scaricare $url dopo $max_retries tentativi.");
    return undef;  # Ritorna undef se il download fallisce
}

# Funzione per determinare la codifica
sub get_encoding {
    my ($response) = @_;
    my $content_type = $response->header('Content-Type');
    if ($content_type && $content_type =~ /charset=([^\s;]+)/) {
        return $1;
    }
    my $parser = HTML::HeadParser->new;
    $parser->parse($response->content);
    return $parser->header('Content-Type') =~ /charset=([^\s;]+)/ ? $1 : 'ISO-8859-1';
}

# Funzione per scaricare e analizzare una pagina
sub download_page {
    my ($url, $depth) = @_;
    return if $depth > $max_depth;
    return if $visited{$url};

    print "[+] Scaricamento: $url\n";
    $visited{$url} = 1;

    # Recupera il contenuto della pagina
    my $response = fetch_url($url);
    unless (defined $response && $response->is_success && defined $response->decoded_content) {
        print "[DEBUG] Contenuto non definito per l'URL: $url, skipping...\n";
        return;
    }

    # Salvataggio della pagina
    my $content = $response->decoded_content;
    my $path = uri_to_path($url);
    my $full_path = "$output_dir/$path";

    # Verifica che la directory di destinazione esista
    unless (-d dirname($full_path)) {
        print "[DEBUG] Creazione della directory " . dirname($full_path) . "\n";
        make_path(dirname($full_path));
    }

    # Scrivi il contenuto del file solo se è definito
    eval {
        #open my $fh, '>', $full_path or die "Impossibile scrivere $full_path: $!";
        #print $fh $content;
        #close $fh;
        my $encoding = get_encoding($response);
        my $content = decode($encoding, $response->content);
        open my $fh, '>:encoding('.$encoding.')', $full_path or die "Impossibile aprire $full_path: $!";
        print $fh $content;
        close $fh;
    };
    if ($@) {
        print "[DEBUG] Errore durante il salvataggio di $url: $@\n";
        return;
    }

    my $parser = HTML::LinkExtor->new(sub {
        my ($tag, %attr) = @_;
        
        # Lista di tag da controllare
        return unless $tag =~ /^(a|img|link|script|iframe|video|audio|source|object|embed|meta|track|form)$/;

        # Estrazione link dai vari attributi
        my $link = $attr{href} || $attr{src} || $attr{data} || $attr{action} || $attr{poster} || ($tag eq 'meta' ? $attr{content} : undef);

        if ($link) {
            # Gestione di meta-refresh
            if ($tag eq 'meta' && $link =~ /URL=([^;]+)/i) {
                $link = $1;
            }

            my $abs_link = URI->new_abs($link, $url)->as_string;

            # Aggiungi alla coda solo link validi HTTP o HTTPS
            if ($abs_link =~ /^https?:\/\//) {
                $queue->enqueue([$abs_link, $depth + 1]);
            }
        }
    });
    $parser->parse($content);
}

# Funzione per registrare gli errori nel file di log
sub log_error {
    my ($message) = @_;
    open my $log_fh, '>>', $log_file or die "Impossibile aprire il file di log: $!";
    print $log_fh "$message\n";
    close $log_fh;
}

# Converte l'URL in un percorso di file
sub uri_to_path {
    my ($uri) = @_;
    $uri =~ s/^https?:\/\/|\/+$//g;
    $uri =~ s/[\:\?\=\&]/_/g;
    return "$uri.html";
}

# Funzione per sanificare il nome della directory (rimuove i caratteri speciali)
sub sanitize_filename {
    my ($filename) = @_;
    $filename =~ s/[^a-zA-Z0-9_-]/_/g;  # Sostituisce caratteri non alfanumerici con _
    return $filename;
}

# Attendi che tutti i thread completino
$_->join() for @threads;

print "[+] Download completato. I file sono in $output_dir\n";

__END__

=head1 NAME

OffLiner - Scaricatore di siti web offline

=head1 SYNOPSIS

  perl offliner.pl --url https://example.com [--max-depth N] [--max-threads N]

=head1 DESCRIPTION

OffLiner è un'utility per scaricare siti web e navigarli offline, mantenendo la struttura e i link.

=head1 OPTIONS

=over 8

=item B<--url>

URL del sito da scaricare. Questo parametro è obbligatorio.

=item B<--user-agent>

User-Agent personalizzato da usare durante il download. Default: 'Mozilla/5.0 (compatible; OffLinerBot/1.0)'.

=item B<--max-depth>

Profondità massima di link da seguire. Default: 50.

=item B<--max-threads>

Numero massimo di thread per il download parallelo. Default: 10.

=back

=head1 CONFIGURATION

=over 8

=item B<$user_agent>

Definisce l'user-agent per le richieste HTTP. Può essere sovrascritto tramite l'opzione --user-agent.

=item B<$max_retries>

Numero massimo di tentativi per ogni richiesta HTTP. Default: 3.

=item B<$log_file>

Nome del file di log per registrare gli errori. Default: 'download_log.txt'.

=back

=head1 FUNCTIONS

=head2 install_module

  install_module($module)

Funzione per installare i moduli Perl mancanti.

=head2 get_site_title

  get_site_title($url)

Ottiene il titolo della pagina web data l'URL.

=head2 fetch_url

  fetch_url($url)

Effettua il download di un URL con retry in caso di errori.

=head2 download_page

  download_page($url, $depth)

Scarica e analizza una pagina web, seguendo i link trovati fino a una certa profondità.

=head2 log_error

  log_error($message)

Registra un messaggio di errore nel file di log.

=head2 uri_to_path

  uri_to_path($uri)

Converte un URI in un percorso di file valido.

=head2 sanitize_filename

  sanitize_filename($filename)

Sanifica il nome della directory rimuovendo i caratteri speciali.

=head1 AUTHOR

OffLiner Team

=head1 LICENSE

Licenza BSD.

=cut

