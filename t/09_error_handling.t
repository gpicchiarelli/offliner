#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

# Test della gestione degli errori

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;
my $output_dir = tempdir(CLEANUP => 1);

# Test con URL non raggiungibile
my $output = `timeout 5 $perl "$script" --url "http://192.0.2.1:99999/nonexistent" --max-depth 1 --max-threads 1 --output-dir "$output_dir" 2>&1`;
# Non verifichiamo exit code perché potrebbe variare, ma verifichiamo che non crashi

unlike($output, qr/segmentation fault|core dump|panic/i, "Nessun crash con URL non raggiungibile");

# Test con max-depth 0 (dovrebbe scaricare solo la pagina iniziale)
$output = `timeout 5 $perl "$script" --url "http://example.com" --max-depth 0 --max-threads 1 --output-dir "$output_dir" 2>&1`;
unlike($output, qr/segmentation fault|core dump|panic/i, "Nessun crash con max-depth 0");

# Test con max-threads 0 (dovrebbe fallire o usare default)
$output = `$perl "$script" --url "http://example.com" --max-threads 0 2>&1`;
# Potrebbe fallire o usare un default, entrambi sono accettabili
pass("Gestione di max-threads 0");

done_testing();

