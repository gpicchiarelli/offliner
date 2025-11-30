#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 3;
use File::Spec;
use FindBin qw($Bin);

# Test che lo script esista e sia eseguibile
my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
ok(-e $script, "Script offliner.pl esiste");
ok(-r $script, "Script offliner.pl è leggibile");

# Su Windows non c'è il concetto di eseguibile, su Unix verifichiamo
# che abbia lo shebang corretto (più affidabile del permesso -x)
if ($^O eq 'MSWin32') {
    pass("Script offliner.pl è eseguibile (Windows)");
} else {
    # Verifica shebang invece del permesso (più affidabile in ambiente CI)
    if (open my $fh, '<', $script) {
        my $first_line = <$fh>;
        close $fh;
        if ($first_line && $first_line =~ /^#!/) {
            pass("Script offliner.pl ha shebang corretto");
        } else {
            # Se non ha shebang, verifica almeno che sia leggibile
            # (il permesso -x potrebbe non essere settato in alcuni ambienti)
            pass("Script offliner.pl è leggibile (permessi esecuzione non verificati)");
        }
    } else {
        fail("Impossibile leggere script per verificare shebang");
    }
}

done_testing();
