#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);

# Test Perl::Critic (opzionale)
SKIP: {
    eval { require Perl::Critic; };
    skip "Perl::Critic non disponibile (installalo con: cpanm Perl::Critic)", 1 if $@;
    
    my $critic = Perl::Critic->new(-profile => "$Bin/../.perlcriticrc");
    
    # Test tutti i file Perl
    my @files = (
        "$Bin/../offliner.pl",
        glob("$Bin/../lib/OffLiner/*.pm"),
        glob("$Bin/../lib/OffLiner/*/*.pm"),
    );
    
    my $errors = 0;
    for my $file (@files) {
        next unless -f $file;
        my @violations = $critic->critique($file);
        if (@violations) {
            diag("Violazioni Perl::Critic in $file:");
            for my $violation (@violations) {
                diag("  " . $violation->description() . " (severity: " . $violation->severity() . ")");
            }
            $errors += scalar(@violations);
        }
    }
    
    # Permetti alcune violazioni (non bloccare il build)
    ok($errors < 50, "Perl::Critic: meno di 50 violazioni totali (trovate: $errors)")
        or diag("Considera di correggere le violazioni più gravi");
}

done_testing();

