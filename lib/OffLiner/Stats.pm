package OffLiner::Stats;

use strict;
use warnings;
use 5.014;
use Time::HiRes qw(time);
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(init_stats update_stats display_stats format_bytes format_time format_rate get_elapsed_time);

# Statistiche globali
my $start_time;
my $last_update_time;
my $last_pages_downloaded = 0;
my $last_pages_failed = 0;
my $total_bytes_downloaded :shared = 0;
my $bytes_lock;
my $first_display = 1;

# Inizializza le statistiche
sub init_stats {
    $start_time = time();
    $last_update_time = $start_time;
    $last_pages_downloaded = 0;
    $last_pages_failed = 0;
    $total_bytes_downloaded = 0;
    $bytes_lock = Thread::Semaphore->new(1);
    $first_display = 1;
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
    
    $last_update_time = $current_time;
    $last_pages_downloaded = $pages_downloaded;
    $last_pages_failed = $pages_failed;
    
    return {
        elapsed => $elapsed,
        pages_downloaded => $pages_downloaded,
        pages_failed => $pages_failed,
        queue_size => $queue_size,
        active_threads => $active_threads,
        visited_count => $visited_count,
        rate => $rate,
        total => $pages_downloaded + $pages_failed,
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
    
    # ANSI color codes
    my $RESET = "\033[0m";
    my $BOLD = "\033[1m";
    my $GREEN = "\033[32m";
    my $RED = "\033[31m";
    my $YELLOW = "\033[33m";
    my $BLUE = "\033[34m";
    my $CYAN = "\033[36m";
    my $MAGENTA = "\033[35m";
    my $WHITE = "\033[37m";
    
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
    my $progress_bar = generate_progress_bar($success_rate, 20);
    
    # Numero di righe da stampare (8 righe totali)
    my $num_lines = 8;
    
    # Se non è la prima visualizzazione, torna indietro di 8 righe
    unless ($first_display) {
        # Torna indietro di 8 righe
        print "\033[${num_lines}A";
    } else {
        # Prima visualizzazione: stampa una riga vuota per separare
        print "\n";
    }
    $first_display = 0;
    
    # Pulisci ogni riga e riscrivi
    my $clear_line = "\033[K";
    
    # Costruisci tutto il blocco in una stringa per evitare problemi di buffering
    my $output = "";
    $output .= "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}${clear_line}\n";
    $output .= "${CYAN}${BOLD}  OffLiner - Download Statistics${RESET}${clear_line}\n";
    $output .= "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}${clear_line}\n";
    
    # Statistiche principali - formato compatto
    $output .= sprintf("${GREEN}[OK]${RESET} %6d  ${RED}[FAIL]${RESET} %4d  ${BLUE}[TOT]${RESET} %6d  ${MAGENTA}[QUEUE]${RESET} %6d${clear_line}\n",
           $stats->{pages_downloaded}, $stats->{pages_failed}, $stats->{total}, $stats->{queue_size});
    
    $output .= sprintf("${YELLOW}[SPEED]${RESET} %8s  ${CYAN}[TIME]${RESET} %10s  ${GREEN}[THREADS]${RESET} %3d  ${BLUE}[VISITED]${RESET} %6d${clear_line}\n",
           format_rate($stats->{rate}), format_time($stats->{elapsed}), $stats->{active_threads}, $stats->{visited_count});
    
    if ($eta ne 'N/A') {
        $output .= sprintf("${MAGENTA}[ETA]${RESET} %10s  ${WHITE}[PROGRESS]${RESET} %s ${BOLD}%5.1f%%${RESET}${clear_line}\n", 
               $eta, $progress_bar, $success_rate);
    } else {
        $output .= sprintf("${MAGENTA}[ETA]${RESET} %10s  ${WHITE}[PROGRESS]${RESET} %s ${BOLD}%5.1f%%${RESET}${clear_line}\n", 
               'N/A', $progress_bar, $success_rate);
    }
    
    # Footer
    $output .= "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════════${RESET}${clear_line}\n";
    
    # Stampa tutto in una volta
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
    
    my $GREEN = "\033[32m";
    my $YELLOW = "\033[33m";
    my $RED = "\033[31m";
    my $RESET = "\033[0m";
    my $BG_GREEN = "\033[42m";
    my $BG_YELLOW = "\033[43m";
    my $BG_RED = "\033[41m";
    
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
    return unless $bytes_lock;
    $bytes_lock->down();
    $total_bytes_downloaded += $bytes;
    $bytes_lock->up();
}

# Ottieni bytes totali
sub get_total_bytes {
    return $total_bytes_downloaded;
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
