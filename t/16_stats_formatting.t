#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Test completi per le funzioni di formattazione
use OffLiner::Stats qw(
    format_bytes 
    format_time 
    format_rate
);

plan tests => 24;

# Test format_bytes - casi limite e normali
{
    is(format_bytes(0), "0 B", "format_bytes(0) = '0 B'");
    is(format_bytes(1), "1.00 B", "format_bytes(1) = '1.00 B'");
    is(format_bytes(1023), "1023.00 B", "format_bytes(1023) = '1023.00 B'");
    is(format_bytes(1024), "1.00 KB", "format_bytes(1024) = '1.00 KB'");
    is(format_bytes(1536), "1.50 KB", "format_bytes(1536) = '1.50 KB'");
    is(format_bytes(1048576), "1.00 MB", "format_bytes(1048576) = '1.00 MB'");
    is(format_bytes(1073741824), "1.00 GB", "format_bytes(1073741824) = '1.00 GB'");
    is(format_bytes(1099511627776), "1.00 TB", "format_bytes(1099511627776) = '1.00 TB'");
    
    # Test valori intermedi
    is(format_bytes(5120), "5.00 KB", "format_bytes(5120) = '5.00 KB'");
    is(format_bytes(5242880), "5.00 MB", "format_bytes(5242880) = '5.00 MB'");
}

# Test format_time - casi limite e normali
{
    is(format_time(0), "0s", "format_time(0) = '0s'");
    is(format_time(1), "1s", "format_time(1) = '1s'");
    is(format_time(30), "30s", "format_time(30) = '30s'");
    is(format_time(60), "1m 0s", "format_time(60) = '1m 0s'");
    is(format_time(90), "1m 30s", "format_time(90) = '1m 30s'");
    is(format_time(3661), "1h 1m 1s", "format_time(3661) = '1h 1m 1s'");
    is(format_time(7323), "2h 2m 3s", "format_time(7323) = '2h 2m 3s'");
    
    # Test valori decimali (vengono arrotondati)
    is(format_time(45.7), "45s", "format_time(45.7) arrotonda correttamente");
}

# Test format_rate - casi limite e normali
{
    like(format_rate(0), qr/0\.00 pag\/s/, "format_rate(0) formatta correttamente");
    like(format_rate(1), qr/1\.00 pag\/s/, "format_rate(1) formatta correttamente");
    like(format_rate(10.5), qr/10\.50 pag\/s/, "format_rate(10.5) formatta correttamente");
    like(format_rate(100.123), qr/100\.12 pag\/s/, "format_rate(100.123) arrotonda a 2 decimali");
    like(format_rate(0.001), qr/0\.00 pag\/s/, "format_rate(0.001) arrotonda correttamente");
    like(format_rate(999.999), qr/1000\.00 pag\/s/, "format_rate(999.999) arrotonda correttamente");
}

done_testing();

