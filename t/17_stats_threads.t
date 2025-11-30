#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Time::HiRes qw(sleep);

# Test per il calcolo dei thread attivi e working
use OffLiner::Stats qw(
    init_stats 
    update_stats 
    display_stats
);

plan tests => 8;

# Test calcolo thread working
{
    init_stats();
    
    # Scenario 1: Tutti i thread attivi (nessuno working)
    my $stats1 = {
        pages_downloaded => 10,
        pages_failed => 0,
        total => 10,
        queue_size => 50,
        active_threads => 10,  # Tutti i thread sono attivi (idle)
        visited_count => 10,
        rate => 5.0,
        elapsed => 2,
        network_speed => 1024,
        total_bytes => 2048,
        max_threads => 10,
    };
    
    local *STDOUT;
    open STDOUT, '>', \my $output1 or die "Impossibile reindirizzare STDOUT";
    
    eval {
        display_stats($stats1);
    };
    
    close STDOUT;
    
    ok(!$@, "display_stats gestisce correttamente tutti i thread attivi");
    like($output1, qr/Threads.*0/, "Threads working = 0 quando tutti sono attivi");
    
    # Scenario 2: Alcuni thread working
    my $stats2 = {
        pages_downloaded => 20,
        pages_failed => 1,
        total => 21,
        queue_size => 30,
        active_threads => 3,  # 3 thread idle, quindi 7 working
        visited_count => 20,
        rate => 10.0,
        elapsed => 4,
        network_speed => 2048,
        total_bytes => 4096,
        max_threads => 10,
    };
    
    open STDOUT, '>', \my $output2 or die "Impossibile reindirizzare STDOUT";
    
    eval {
        display_stats($stats2);
    };
    
    close STDOUT;
    
    ok(!$@, "display_stats gestisce correttamente alcuni thread working");
    like($output2, qr/Threads.*7/, "Threads working = 7 quando 3 sono attivi su 10");
    
    # Scenario 3: Nessun thread attivo (tutti working)
    my $stats3 = {
        pages_downloaded => 30,
        pages_failed => 2,
        total => 32,
        queue_size => 20,
        active_threads => 0,  # Nessun thread idle, tutti working
        visited_count => 30,
        rate => 15.0,
        elapsed => 6,
        network_speed => 4096,
        total_bytes => 8192,
        max_threads => 10,
    };
    
    open STDOUT, '>', \my $output3 or die "Impossibile reindirizzare STDOUT";
    
    eval {
        display_stats($stats3);
    };
    
    close STDOUT;
    
    ok(!$@, "display_stats gestisce correttamente tutti i thread working");
    like($output3, qr/Threads.*10/, "Threads working = 10 quando nessuno è attivo");
    
    # Scenario 4: max_threads non definito (fallback)
    my $stats4 = {
        pages_downloaded => 40,
        pages_failed => 3,
        total => 43,
        queue_size => 10,
        active_threads => 5,
        visited_count => 40,
        rate => 20.0,
        elapsed => 8,
        network_speed => 8192,
        total_bytes => 16384,
        # max_threads non definito
    };
    
    open STDOUT, '>', \my $output4 or die "Impossibile reindirizzare STDOUT";
    
    eval {
        display_stats($stats4);
    };
    
    close STDOUT;
    
    ok(!$@, "display_stats gestisce correttamente max_threads non definito");
    like($output4, qr/Threads/, "display_stats mostra Threads anche senza max_threads");
}

done_testing();

