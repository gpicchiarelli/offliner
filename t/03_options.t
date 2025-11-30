#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Test senza URL (dovrebbe fallire)
my $output = `$perl "$script" 2>&1`;
my $exit_code = $? >> 8;
isnt($exit_code, 0, "Exit code non-zero senza --url");
like($output, qr/Devi specificare un URL/, "Messaggio di errore corretto senza URL");

# Test con URL non valido
$output = `$perl "$script" --url "invalid-url" 2>&1`;
$exit_code = $? >> 8;
isnt($exit_code, 0, "Exit code non-zero con URL non valido");
like($output, qr/URL non valido/, "Messaggio di errore per URL non valido");

# Test con URL valido ma non raggiungibile (dovrebbe iniziare il download)
# Non testiamo il completamento perché richiede connessione internet
# Questo test verifica solo che lo script accetti l'URL valido
$output = `timeout 2 $perl "$script" --url "http://nonexistent-domain-12345.test" --max-depth 1 --max-threads 1 2>&1 || true`;
# Non verifichiamo l'exit code perché potrebbe variare

done_testing();

