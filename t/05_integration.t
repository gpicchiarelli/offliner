#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use Cwd qw(cwd);

# Questo test richiede HTTP::Server::Simple o un server mock
# Per ora testiamo solo che lo script funzioni con directory temporanee

SKIP: {
    skip "Test di integrazione richiede moduli aggiuntivi", 1 unless eval { require HTTP::Server::Simple; 1 };
    
    my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
    my $perl = $^X;
    
    # Crea una directory temporanea che verrà rimossa automaticamente
    my $tempdir = tempdir(CLEANUP => 1);
    
    # Test che la directory temporanea esista
    ok(-d $tempdir, "Directory temporanea creata");
    
    # Nota: Per un test completo di integrazione, servirebbe un server HTTP mock
    # Questo è un placeholder per test futuri
}

done_testing();

