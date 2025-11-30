#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Test per il display delle statistiche
use OffLiner::Stats qw(
    init_stats 
    update_stats 
    display_stats 
    add_bytes
);

plan tests => 11;

# Test che display_stats non crashi con vari scenari
{
    init_stats();
    
    # Scenario 1: Statistiche iniziali (tutto a zero)
    {
        local *STDOUT;
        open STDOUT, '>', \my $output or die "Impossibile reindirizzare STDOUT";
        
        my $stats = {
            pages_downloaded => 0,
            pages_failed => 0,
            total => 0,
            queue_size => 0,
            active_threads => 0,
            visited_count => 0,
            rate => 0,
            elapsed => 0,
            network_speed => 0,
            total_bytes => 0,
            max_threads => 10,
        };
        
        eval {
            display_stats($stats);
        };
        
        close STDOUT;
        
        ok(!$@, "display_stats gestisce correttamente statistiche iniziali");
        ok(length($output) > 0, "display_stats produce output anche con valori zero");
    }
    
    # Scenario 2: Download in corso
    {
        init_stats();
        add_bytes(10240);  # 10 KB
        
        local *STDOUT;
        open STDOUT, '>', \my $output or die "Impossibile reindirizzare STDOUT";
        
        my $stats = {
            pages_downloaded => 50,
            pages_failed => 2,
            total => 52,
            queue_size => 100,
            active_threads => 3,
            visited_count => 60,
            rate => 15.5,
            elapsed => 5,
            network_speed => 2048,
            total_bytes => 10240,
            max_threads => 10,
        };
        
        eval {
            display_stats($stats);
        };
        
        close STDOUT;
        
        ok(!$@, "display_stats gestisce correttamente download in corso");
        like($output, qr/OK.*50/, "display_stats mostra pagine scaricate");
        like($output, qr/FAIL.*2/, "display_stats mostra pagine fallite");
        like($output, qr/Queue.*100/, "display_stats mostra coda");
        like($output, qr/Threads/, "display_stats mostra thread");
    }
    
    # Scenario 3: Download completato
    {
        init_stats();
        add_bytes(51200);  # 50 KB
        
        local *STDOUT;
        open STDOUT, '>', \my $output or die "Impossibile reindirizzare STDOUT";
        
        my $stats = {
            pages_downloaded => 100,
            pages_failed => 0,
            total => 100,
            queue_size => 0,
            active_threads => 0,
            visited_count => 100,
            rate => 20.0,
            elapsed => 10,
            network_speed => 5120,
            total_bytes => 51200,
            max_threads => 10,
        };
        
        eval {
            display_stats($stats);
        };
        
        close STDOUT;
        
        ok(!$@, "display_stats gestisce correttamente download completato");
        like($output, qr/NET/, "display_stats mostra velocità di rete");
        like($output, qr/ETA/, "display_stats mostra ETA");
    }
    
    # Scenario 4: Valori molto grandi
    {
        init_stats();
        add_bytes(1073741824);  # 1 GB
        
        local *STDOUT;
        open STDOUT, '>', \my $output or die "Impossibile reindirizzare STDOUT";
        
        my $stats = {
            pages_downloaded => 10000,
            pages_failed => 50,
            total => 10050,
            queue_size => 5000,
            active_threads => 5,
            visited_count => 15000,
            rate => 100.0,
            elapsed => 3600,
            network_speed => 1048576,
            total_bytes => 1073741824,
            max_threads => 10,
        };
        
        eval {
            display_stats($stats);
        };
        
        close STDOUT;
        
        ok(!$@, "display_stats gestisce correttamente valori molto grandi");
    }
}

done_testing();

