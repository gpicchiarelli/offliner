#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Test completo per OffLiner::Stats
use OffLiner::Stats qw(
    init_stats 
    update_stats 
    display_stats 
    format_bytes 
    format_time 
    format_rate 
    add_bytes 
    get_total_bytes 
    get_elapsed_time
);

plan tests => 37;

# Test 1-3: init_stats
{
    init_stats();
    my $elapsed = get_elapsed_time();
    ok($elapsed >= 0, "init_stats inizializza correttamente - elapsed time >= 0");
    ok($elapsed < 1, "init_stats inizializza correttamente - elapsed time < 1 secondo");
    
    my $total_bytes = get_total_bytes();
    is($total_bytes, 0, "init_stats inizializza bytes totali a 0");
}

# Test 4-8: format_bytes
{
    is(format_bytes(0), "0 B", "format_bytes(0) restituisce '0 B'");
    is(format_bytes(1023), "1023.00 B", "format_bytes(1023) restituisce bytes");
    is(format_bytes(1024), "1.00 KB", "format_bytes(1024) restituisce KB");
    is(format_bytes(1048576), "1.00 MB", "format_bytes(1048576) restituisce MB");
    is(format_bytes(1073741824), "1.00 GB", "format_bytes(1073741824) restituisce GB");
}

# Test 9-14: format_time
{
    is(format_time(0), "0s", "format_time(0) restituisce '0s'");
    is(format_time(1), "1s", "format_time(1) restituisce secondi");
    is(format_time(60), "1m 0s", "format_time(60) restituisce minuti e secondi");
    is(format_time(3661), "1h 1m 1s", "format_time(3661) restituisce ore, minuti e secondi");
    is(format_time(90), "1m 30s", "format_time(90) restituisce minuti e secondi");
    is(format_time(45), "45s", "format_time(45) restituisce solo secondi");
}

# Test 15-17: format_rate
{
    like(format_rate(0), qr/0\.00 pag\/s/, "format_rate(0) formatta correttamente");
    like(format_rate(10.5), qr/10\.50 pag\/s/, "format_rate(10.5) formatta correttamente");
    like(format_rate(100.123), qr/100\.12 pag\/s/, "format_rate(100.123) formatta correttamente");
}

# Test 18-22: add_bytes e get_total_bytes
{
    init_stats();
    is(get_total_bytes(), 0, "get_total_bytes() restituisce 0 dopo init");
    
    add_bytes(100);
    is(get_total_bytes(), 100, "add_bytes(100) aggiunge correttamente");
    
    add_bytes(50);
    is(get_total_bytes(), 150, "add_bytes(50) aggiunge correttamente al totale");
    
    add_bytes(0);
    is(get_total_bytes(), 150, "add_bytes(0) non modifica il totale");
    
    add_bytes(-10);
    is(get_total_bytes(), 150, "add_bytes(-10) non modifica il totale (valore negativo ignorato)");
}

# Test 23-32: update_stats
{
    init_stats();
    
    # Simula un po' di tempo
    sleep(1);
    
    my $stats = update_stats(10, 2, 5, 3, 15);
    
    ok(defined $stats, "update_stats restituisce un hashref");
    is($stats->{pages_downloaded}, 10, "update_stats traccia correttamente pages_downloaded");
    is($stats->{pages_failed}, 2, "update_stats traccia correttamente pages_failed");
    is($stats->{queue_size}, 5, "update_stats traccia correttamente queue_size");
    is($stats->{active_threads}, 3, "update_stats traccia correttamente active_threads");
    is($stats->{visited_count}, 15, "update_stats traccia correttamente visited_count");
    is($stats->{total}, 12, "update_stats calcola correttamente total");
    ok($stats->{elapsed} >= 1, "update_stats calcola correttamente elapsed time");
    ok($stats->{rate} >= 0, "update_stats calcola correttamente rate");
    ok(defined $stats->{network_speed}, "update_stats include network_speed");
    ok(defined $stats->{total_bytes}, "update_stats include total_bytes");
    is($stats->{total_bytes}, 0, "update_stats include total_bytes inizializzato a 0");
}

# Test 28-30: display_stats (verifica che non crashi)
{
    init_stats();
    
    # Cattura l'output
    local *STDOUT;
    open STDOUT, '>', \my $output or die "Impossibile reindirizzare STDOUT";
    
    my $stats = {
        pages_downloaded => 100,
        pages_failed => 5,
        total => 105,
        queue_size => 50,
        active_threads => 2,
        visited_count => 150,
        rate => 10.5,
        elapsed => 10,
        network_speed => 102400,
        total_bytes => 1024000,
        max_threads => 10,
    };
    
    eval {
        display_stats($stats);
    };
    
    close STDOUT;
    
    ok(!$@, "display_stats non genera errori");
    ok(length($output) > 0, "display_stats produce output");
    like($output, qr/OffLiner/, "display_stats contiene 'OffLiner'");
}

done_testing();

