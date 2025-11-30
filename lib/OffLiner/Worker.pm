package OffLiner::Worker;

use strict;
use warnings;
use 5.014;
use OffLiner::Downloader qw(create_user_agent download_page);
use OffLiner::Config;

our $VERSION = '1.0.0';

# Thread worker
sub worker_thread {
    my ($params) = @_;
    
    my $user_agent = $params->{user_agent};
    my $max_retries = $params->{max_retries};
    my $max_depth = $params->{max_depth};
    my $output_dir = $params->{output_dir};
    my $queue = $params->{queue};
    my $visited = $params->{visited};
    my $visited_lock = $params->{visited_lock};
    my $pages_downloaded = $params->{pages_downloaded};
    my $pages_failed = $params->{pages_failed};
    my $pages_lock = $params->{pages_lock};
    my $terminate = $params->{terminate};
    my $active_threads = $params->{active_threads};
    my $threads_lock = $params->{threads_lock};
    my $verbose = $params->{verbose};
    my $SENTINEL = $params->{SENTINEL};
    
    # Crea un LWP::UserAgent per thread (riutilizzabile)
    my $ua = create_user_agent($user_agent, OffLiner::Config::DEFAULT_TIMEOUT());
    
    # Cache per directory già create (per thread)
    my %dir_cache;
    
    # Ottimizzazione: batch di bytes per ridurre lock contention
    my $bytes_batch = 0;
    my $BATCH_SIZE = 10000;  # Accumula fino a 10KB prima di aggiornare
    
    while (!$$terminate) {
        # Usa dequeue_timed per evitare busy waiting
        my $job = $queue->dequeue_timed(1);
        if (!defined $job) {
            # Timeout - thread inattivo (aggiorna batch se necessario)
            if ($bytes_batch > 0) {
                eval {
                    require OffLiner::Stats;
                    OffLiner::Stats::add_bytes($bytes_batch);
                };
                $bytes_batch = 0;
            }
            
            # Aggiorna stato thread una sola volta
            $threads_lock->down();
            $$active_threads--;
            $threads_lock->up();
            
            # Aspetta un po' prima di riprovare
            sleep 0.1;
            
            $threads_lock->down();
            $$active_threads++;
            $threads_lock->up();
            next;
        }
        
        last if $job eq $SENTINEL;
        
        # Thread attivo - aggiorna stato una sola volta
        $threads_lock->down();
        $$active_threads--;
        $threads_lock->up();
        
        my ($url, $depth) = @$job;
        download_page(
            $url, $depth, $ua, $output_dir, $max_depth, $max_retries,
            $visited, $visited_lock, $queue, $terminate,
            $pages_downloaded, $pages_failed, $pages_lock,
            \%dir_cache, $verbose, \$bytes_batch, $BATCH_SIZE
        );
        
        $threads_lock->down();
        $$active_threads++;
        $threads_lock->up();
    }
    
    # Flush finale del batch (assicurati che venga sempre eseguito)
    if ($bytes_batch > 0) {
        eval {
            require OffLiner::Stats;
            OffLiner::Stats::add_bytes($bytes_batch);
            $bytes_batch = 0;  # Reset dopo flush
        };
    }
    
    # Thread terminato
    $threads_lock->down();
    $$active_threads--;
    $threads_lock->up();
}

1;

__END__

=encoding UTF-8

=head1 NAME

OffLiner::Worker - Thread worker per download parallelo

=head1 SYNOPSIS

    use OffLiner::Worker;

    my $thread = threads->create(\&OffLiner::Worker::worker_thread, $params);

=head1 DESCRIPTION

Implementa il thread worker che processa i job dalla coda per il download parallelo.

=head1 FUNCTIONS

=over 4

=item B<worker_thread($params)>

Funzione principale del thread worker. Riceve un hashref con tutti i parametri necessari.

=back

=cut

