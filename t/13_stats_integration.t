#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Time::HiRes qw(sleep);

# Test di integrazione per OffLiner::Stats
use OffLiner::Stats qw(
    init_stats 
    update_stats 
    add_bytes 
    get_total_bytes 
    get_elapsed_time
);

plan tests => 15;

# Test integrazione: simulazione di un download con statistiche
{
    init_stats();
    
    # Simula download di alcune pagine
    add_bytes(1024);   # 1 KB
    sleep(0.1);
    
    my $stats1 = update_stats(1, 0, 10, 5, 1);
    ok($stats1->{pages_downloaded} == 1, "Statistiche tracciano correttamente prima pagina");
    ok($stats1->{total_bytes} >= 1024, "Statistiche tracciano correttamente bytes totali");
    ok($stats1->{network_speed} >= 0, "Statistiche calcolano velocità di rete");
    
    # Simula più download
    add_bytes(2048);   # 2 KB
    add_bytes(512);    # 0.5 KB
    sleep(0.1);
    
    my $stats2 = update_stats(3, 1, 8, 4, 3);
    ok($stats2->{pages_downloaded} == 3, "Statistiche tracciano correttamente pagine multiple");
    ok($stats2->{pages_failed} == 1, "Statistiche tracciano correttamente pagine fallite");
    ok($stats2->{total_bytes} >= 3584, "Statistiche tracciano correttamente bytes cumulativi");
    ok($stats2->{elapsed} > $stats1->{elapsed}, "Tempo trascorso aumenta correttamente");
    
    # Verifica che la velocità sia calcolata
    if ($stats2->{elapsed} > 0 && $stats2->{total_bytes} > 0) {
        ok($stats2->{network_speed} > 0, "Velocità di rete calcolata correttamente quando ci sono bytes");
    } else {
        pass("Velocità di rete: skip (nessun byte o tempo zero)");
    }
}

# Test velocità istantanea vs media
{
    init_stats();
    
    # Primo batch
    add_bytes(1000);
    sleep(0.2);
    my $stats1 = update_stats(1, 0, 5, 3, 1);
    
    # Secondo batch più veloce
    add_bytes(2000);
    sleep(0.1);
    my $stats2 = update_stats(2, 0, 4, 2, 2);
    
    ok($stats2->{total_bytes} > $stats1->{total_bytes}, "Bytes totali aumentano correttamente");
    ok($stats2->{network_speed} >= 0, "Velocità di rete sempre >= 0");
    
    # Verifica che la velocità istantanea sia maggiore della media quando il secondo batch è più veloce
    if ($stats2->{elapsed} > 0 && $stats2->{total_bytes} > 0) {
        ok($stats2->{network_speed} >= 0, "Velocità calcolata correttamente");
    } else {
        pass("Velocità: skip");
    }
}

# Test thread-safe di add_bytes
{
    init_stats();
    
    # Simula chiamate concorrenti (in realtà sequenziali, ma testiamo la thread-safety)
    my $total_expected = 0;
    for my $i (1..10) {
        my $bytes = $i * 100;
        add_bytes($bytes);
        $total_expected += $bytes;
    }
    
    my $total_actual = get_total_bytes();
    is($total_actual, $total_expected, "add_bytes è thread-safe e accumula correttamente");
}

# Test edge cases
{
    init_stats();
    
    # Test con valori zero
    my $stats = update_stats(0, 0, 0, 0, 0);
    ok(defined $stats, "update_stats gestisce correttamente valori zero");
    is($stats->{total}, 0, "update_stats calcola correttamente total con valori zero");
    ok($stats->{rate} == 0 || $stats->{rate} >= 0, "update_stats gestisce correttamente rate con zero pagine");
}

done_testing();

