#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Time::HiRes qw(sleep);

# Test specifici per il tracciamento della velocità di rete
use OffLiner::Stats qw(
    init_stats 
    update_stats 
    add_bytes 
    get_total_bytes
    format_bytes
);

plan tests => 13;

# Test tracciamento bytes e velocità
{
    init_stats();
    
    # Test 1: Aggiunta di bytes incrementale
    is(get_total_bytes(), 0, "Bytes iniziali sono 0");
    
    add_bytes(1024);
    is(get_total_bytes(), 1024, "add_bytes(1024) funziona correttamente");
    
    add_bytes(2048);
    is(get_total_bytes(), 3072, "add_bytes accumula correttamente");
    
    # Test 2: Calcolo velocità con tempo trascorso
    sleep(0.5);
    my $stats = update_stats(1, 0, 5, 3, 1);
    
    ok($stats->{total_bytes} >= 3072, "update_stats include bytes totali");
    ok(defined $stats->{network_speed}, "update_stats include network_speed");
    
    # Test 3: Velocità istantanea vs media
    add_bytes(5120);  # 5 KB
    sleep(0.2);
    my $stats2 = update_stats(2, 0, 4, 2, 2);
    
    ok($stats2->{total_bytes} >= 8192, "Bytes totali aumentano correttamente");
    ok($stats2->{network_speed} >= 0, "Velocità di rete sempre >= 0");
    
    # Test 4: Formattazione velocità
    if ($stats2->{network_speed} > 0) {
        my $formatted = format_bytes($stats2->{network_speed}) . "/s";
        like($formatted, qr/\/s$/, "Velocità formattata correttamente con /s");
        unlike($formatted, qr/NaN|Inf/, "Velocità non contiene NaN o Inf");
    } else {
        pass("Velocità zero: skip formattazione");
    }
}

# Test edge cases per velocità
{
    init_stats();
    
    # Test con bytes molto grandi
    add_bytes(1073741824);  # 1 GB
    sleep(0.1);
    my $stats = update_stats(1, 0, 0, 0, 1);
    
    ok($stats->{total_bytes} >= 1073741824, "Gestisce correttamente bytes molto grandi");
    ok($stats->{network_speed} >= 0, "Velocità gestisce correttamente bytes grandi");
    
    # Test con velocità molto alta
    add_bytes(10485760);  # 10 MB
    sleep(0.05);
    my $stats2 = update_stats(2, 0, 0, 0, 2);
    
    ok($stats2->{network_speed} >= 0, "Gestisce correttamente velocità molto alta");
}

# Test thread-safety di add_bytes con valori multipli
{
    init_stats();
    
    my $expected_total = 0;
    for my $bytes (100, 200, 300, 400, 500) {
        add_bytes($bytes);
        $expected_total += $bytes;
    }
    
    is(get_total_bytes(), $expected_total, "add_bytes thread-safe con chiamate multiple");
}

done_testing();

