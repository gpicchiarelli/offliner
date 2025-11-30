#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

# Test che lo script mostri l'help quando richiesto
my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Test --help
my $output = `$perl "$script" --help 2>&1`;
my $exit_code = $? >> 8;

is($exit_code, 0, "Exit code 0 con --help");
like($output, qr/Uso:/, "Output contiene 'Uso:'");
like($output, qr/--url/, "Output contiene '--url'");
like($output, qr/--help/, "Output contiene '--help'");

done_testing();


