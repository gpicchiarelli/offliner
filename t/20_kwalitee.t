#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

# Test Kwalitee (qualità distribuzione CPAN)
# Questo test verifica che la distribuzione abbia una buona qualità

plan tests => 10;

# 1. Verifica file essenziali
ok(-f "$Bin/../Makefile.PL", "Makefile.PL presente");
ok(-f "$Bin/../META.json", "META.json presente");
ok(-f "$Bin/../MANIFEST", "MANIFEST presente");
ok(-f "$Bin/../README.md", "README.md presente");
ok(-f "$Bin/../LICENSE", "LICENSE presente");
ok(-f "$Bin/../Changes", "Changes presente");

# 2. Verifica struttura directory
ok(-d "$Bin/../lib", "Directory lib/ presente");
ok(-d "$Bin/../t", "Directory t/ presente");

# 3. Verifica che ci siano test
my @test_files = glob("$Bin/*.t");
ok(scalar(@test_files) > 0, "Almeno un file di test presente");

# 4. Verifica che ci siano moduli
my @module_files = glob("$Bin/../lib/OffLiner/*.pm");
ok(scalar(@module_files) > 0, "Almeno un modulo presente");

done_testing();

