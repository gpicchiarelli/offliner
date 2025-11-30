#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

# Test che lo script abbia sintassi Perl valida
my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');

# Esegui perl -c per verificare la sintassi
my $perl = $^X;
my $output = `$perl -c "$script" 2>&1`;
my $exit_code = $? >> 8;

is($exit_code, 0, "Sintassi Perl valida")
    or diag("Output: $output");

done_testing();


