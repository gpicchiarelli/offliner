package OffLiner::Stats;

use strict;
use warnings;
use 5.014;
use Time::HiRes qw(time);
use Thread::Semaphore;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(init_stats update_stats display_stats format_bytes format_time format_rate get_elapsed_time add_bytes get_total_bytes invalidate_bytes_cache);

# Statistiche globali
my $start_time;
my $last_update_time;
my $last_pages_downloaded = 0;
my $last_pages_failed = 0;
my $total_bytes_downloaded :shared = 0;
my $last_bytes_downloaded = 0;
my $bytes_lock;
my $first_display = 1;

# Inizializza le statistiche
sub init_stats {
    $start_time = time();
    $last_update_time = $start_time;
    $last_pages_downloaded = 0;
    $last_pages_failed = 0;
    $total_bytes_downloaded = 0;
    $last_bytes_downloaded = 0;
    $bytes_lock = Thread::Semaphore->new(1);
    $first_display = 1;
}

# Ottimizzazione: cache per evitare chiamate ripetute a get_total_bytes
my $cached_total_bytes = 0;
my $bytes_cache_time = 0;
my $BYTES_CACHE_TTL = 0.05;  # Cache per 50ms (ridotto per aggiornamenti più frequenti)

# Funzione per invalidare la cache dei bytes (chiamata quando si aggiungono bytes)
sub invalidate_bytes_cache {
    $bytes_cache_time = 0;
    $cached_total_bytes = 0;
}

# Aggiorna le statistiche (chiamato periodicamente)
sub update_stats {
    my ($pages_downloaded, $pages_failed, $queue_size, $active_threads, $visited_count) = @_;
    
    my $current_time = time();
    my $elapsed = $current_time - $start_time;
    my $time_since_last = $current_time - $last_update_time;
    
    # Calcola velocità (pagine/secondo)
    my $pages_diff = $pages_downloaded - $last_pages_downloaded;
    my $rate = $time_since_last > 0 ? $pages_diff / $time_since_last : 0;
    
    # Ottimizzazione: cache get_total_bytes per ridurre lock contention
    # Ma aggiorna sempre se è passato abbastanza tempo o se la cache è vuota
    my $total_bytes;
    if ($current_time - $bytes_cache_time < $BYTES_CACHE_TTL && $cached_total_bytes >= 0) {
        $total_bytes = $cached_total_bytes;
    } else {
        $total_bytes = get_total_bytes();
        $cached_total_bytes = $total_bytes;
        $bytes_cache_time = $current_time;
    }
    
    my $bytes_diff = $total_bytes - $last_bytes_downloaded;
    # Usa velocità istantanea se disponibile, altrimenti velocità media
    my $network_speed = 0;
    if ($time_since_last > 0 && $bytes_diff > 0) {
        $network_speed = $bytes_diff / $time_since_last;  # Velocità istantanea
    } elsif ($elapsed > 0 && $total_bytes > 0) {
        $network_speed = $total_bytes / $elapsed;  # Velocità media di fallback
    }
    
    # Aggiorna tutti i valori di stato
    $last_update_time = $current_time;
    $last_pages_downloaded = $pages_downloaded;
    $last_pages_failed = $pages_failed;
    $last_bytes_downloaded = $total_bytes;
    
    return {
        elapsed => $elapsed,
        pages_downloaded => $pages_downloaded,
        pages_failed => $pages_failed,
        queue_size => $queue_size,
        active_threads => $active_threads,
        visited_count => $visited_count,
        rate => $rate,
        total => $pages_downloaded + $pages_failed,
        network_speed => $network_speed,
        total_bytes => $total_bytes,
    };
}

# Formatta bytes in formato leggibile
sub format_bytes {
    my ($bytes) = @_;
    return '0 B' if $bytes == 0;
    
    my @units = qw(B KB MB GB TB);
    my $unit = 0;
    my $size = $bytes;
    
    while ($size >= 1024 && $unit < $#units) {
        $size /= 1024;
        $unit++;
    }
    
    return sprintf("%.2f %s", $size, $units[$unit]);
}

# Formatta tempo in formato leggibile
sub format_time {
    my ($seconds) = @_;
    return '0s' if $seconds < 1;
    
    my $hours = int($seconds / 3600);
    my $minutes = int(($seconds % 3600) / 60);
    my $secs = int($seconds % 60);
    
    if ($hours > 0) {
        return sprintf("%dh %dm %ds", $hours, $minutes, $secs);
    } elsif ($minutes > 0) {
        return sprintf("%dm %ds", $minutes, $secs);
    } else {
        return sprintf("%ds", $secs);
    }
}

# Formatta velocità
sub format_rate {
    my ($rate) = @_;
    return sprintf("%.2f pag/s", $rate);
}

# Stampa statistiche con formattazione moderna e pulita
sub display_stats {
    my ($stats) = @_;
    
    # Assicura che STDOUT gestisca UTF-8 correttamente
    binmode STDOUT, ':utf8';
    
    # ANSI color codes - schema scuro e adattabile ai temi
    my $RESET = "\033[0m";
    my $BOLD = "\033[1m";
    # Colori più scuri e neutri che funzionano bene su temi chiari e scuri
    my $GREEN = "\033[38;5;34m";      # Verde scuro
    my $RED = "\033[38;5;88m";        # Rosso scuro
    my $YELLOW = "\033[38;5;136m";    # Giallo/arancione scuro
    my $BLUE = "\033[38;5;24m";       # Blu scuro
    my $CYAN = "\033[38;5;30m";       # Ciano scuro
    my $MAGENTA = "\033[38;5;90m";    # Magenta scuro
    my $WHITE = "\033[38;5;250m";     # Grigio chiaro (più neutro del bianco)
    
    # Calcola tempo stimato rimanente
    my $eta = 'N/A';
    if ($stats->{rate} > 0 && $stats->{queue_size} > 0) {
        my $remaining = $stats->{queue_size} / $stats->{rate};
        $eta = format_time($remaining);
    }
    
    # Calcola percentuale di successo
    my $success_rate = 0;
    if ($stats->{total} > 0) {
        $success_rate = ($stats->{pages_downloaded} / $stats->{total}) * 100;
    }
    
    # Progress bar semplice
    my $progress_bar = generate_progress_bar($success_rate, 15);
    
    # Calcola thread attivi (lavoranti) = max_threads - thread_in_attesa
    my $max_threads = $stats->{max_threads} // 0;
    my $threads_working = $max_threads > 0 ? ($max_threads - $stats->{active_threads}) : 0;
    
    # Usa una singola riga che si aggiorna con \r (carriage return)
    # Questo evita problemi con le sequenze ANSI per tornare indietro
    my $clear_line = "\033[K";  # Pulisci fino alla fine della riga
    
    # Alla prima visualizzazione, stampa un newline per separare
    if ($first_display) {
        print "\n";
        $first_display = 0;
    }
    
    # Costruisci una singola riga compatta con tutte le statistiche
    my $output = "\r";  # Torna all'inizio della riga
    
    # Formatta velocità di rete (assicurati che sia un numero valido)
    my $network_speed = $stats->{network_speed} || 0;
    my $network_speed_str = ($network_speed > 0) ? (format_bytes($network_speed) . "/s") : "0 B/s";
    
    $output .= sprintf("${CYAN}${BOLD}[OffLiner]${RESET} ${GREEN}OK:${RESET}%5d ${RED}FAIL:${RESET}%4d ${BLUE}TOT:${RESET}%5d ${MAGENTA}Queue:${RESET}%5d ${YELLOW}SPD:${RESET}%6s ${CYAN}T:${RESET}%6s ${GREEN}Threads:${RESET}%2d ${BLUE}Visited:${RESET}%5d ${YELLOW}NET:${RESET}%8s ${MAGENTA}ETA:${RESET}%6s ${WHITE}[%s]${RESET}%5.1f%%",
           $stats->{pages_downloaded}, 
           $stats->{pages_failed}, 
           $stats->{total}, 
           $stats->{queue_size},
           format_rate($stats->{rate}),
           format_time($stats->{elapsed}),
           $threads_working,
           $stats->{visited_count},
           $network_speed_str,
           $eta,
           $progress_bar,
           $success_rate
    );
    
    $output .= $clear_line;  # Pulisci il resto della riga
    
    # Stampa la riga (senza \n, così si sovrascrive)
    print $output;
    
    # Forza il flush per assicurarsi che tutto venga stampato
    STDOUT->flush();
}

# Genera una progress bar semplice
sub generate_progress_bar {
    my ($percentage, $width) = @_;
    $percentage = 0 if $percentage < 0;
    $percentage = 100 if $percentage > 100;
    
    my $filled = int(($percentage / 100) * $width);
    my $empty = $width - $filled;
    
    # Colori scuri per la progress bar
    my $GREEN = "\033[38;5;34m";
    my $YELLOW = "\033[38;5;136m";
    my $RED = "\033[38;5;88m";
    my $RESET = "\033[0m";
    # Background colors più scuri
    my $BG_GREEN = "\033[48;5;22m";   # Verde molto scuro
    my $BG_YELLOW = "\033[48;5;94m";  # Giallo/arancione scuro
    my $BG_RED = "\033[48;5;52m";     # Rosso molto scuro
    
    my $color = $BG_GREEN;
    if ($percentage < 50) {
        $color = $BG_YELLOW;
    }
    if ($percentage < 25) {
        $color = $BG_RED;
    }
    
    my $bar = $color . (' ' x $filled) . $RESET . (' ' x $empty);
    return "[$bar]";
}

# Aggiungi bytes scaricati (thread-safe)
sub add_bytes {
    my ($bytes) = @_;
    return unless defined $bytes && $bytes > 0;
    # Inizializza il lock se non esiste (per sicurezza)
    unless ($bytes_lock) {
        $bytes_lock = Thread::Semaphore->new(1);
    }
    $bytes_lock->down();
    $total_bytes_downloaded += $bytes;
    $bytes_lock->up();
    
    # Invalida la cache per forzare l'aggiornamento nelle statistiche
    invalidate_bytes_cache();
}

# Ottieni bytes totali (thread-safe)
sub get_total_bytes {
    return 0 unless $bytes_lock;
    $bytes_lock->down();
    my $bytes = $total_bytes_downloaded;
    $bytes_lock->up();
    return $bytes;
}

# Ottieni tempo trascorso dall'inizio
sub get_elapsed_time {
    return time() - $start_time if $start_time;
    return 0;
}

1;

__END__

=head1 NAME

OffLiner::Stats - Sistema di statistiche per OffLiner

=head1 SYNOPSIS

    use OffLiner::Stats qw(init_stats update_stats display_stats);
    
    init_stats();
    my $stats = update_stats($pages_downloaded, $pages_failed, $queue_size, $active_threads, $visited_count);
    display_stats($stats);

=head1 DESCRIPTION

Gestisce le statistiche in tempo reale del download, inclusa velocità, tempo trascorso,
tempo stimato rimanente e visualizzazione moderna con colori.

=head1 FUNCTIONS

=over 4

=item B<init_stats()>

Inizializza le statistiche.

=item B<update_stats($pages_downloaded, $pages_failed, $queue_size, $active_threads, $visited_count)>

Aggiorna e calcola le statistiche. Restituisce un hashref con tutte le statistiche.

=item B<display_stats($stats)>

Mostra le statistiche con formattazione moderna e colorata.

=item B<format_bytes($bytes)>

Formatta bytes in formato leggibile (KB, MB, GB).

=item B<format_time($seconds)>

Formatta secondi in formato leggibile (h m s).

=item B<format_rate($rate)>

Formatta velocità in pagine/secondo.

=back

=cut
