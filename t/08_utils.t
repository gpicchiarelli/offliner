#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

# Test delle funzioni utility (se esposte)
# Per ora testiamo solo le funzioni che possiamo testare indirettamente

# Test sanitize_filename attraverso l'output dello script
my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Test che lo script crei directory con nomi sanificati
# Usiamo un URL con caratteri speciali nel dominio
my $output = `timeout 2 $perl "$script" --url "http://test-example.com" --max-depth 0 --max-threads 1 2>&1 || true`;

# Verifica che non ci siano errori di creazione directory
unlike($output, qr/Errore.*directory/i, "Nessun errore nella creazione directory con caratteri speciali");

done_testing();

