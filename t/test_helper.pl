#!/usr/bin/env perl

# Helper per i test - fornisce funzioni comuni e cleanup automatico

package TestHelper;

use strict;
use warnings;
use File::Temp qw(tempdir);
use File::Path qw(rmtree);
use Cwd qw(cwd);

# Directory temporanee create durante i test
our @TEMP_DIRS = ();

# Registra una directory temporanea per cleanup automatico
sub register_tempdir {
    my ($dir) = @_;
    push @TEMP_DIRS, $dir;
    return $dir;
}

# Cleanup automatico alla fine dei test
END {
    for my $dir (@TEMP_DIRS) {
        if (-d $dir) {
            eval {
                rmtree($dir, { error => \my $err });
                if (@$err) {
                    warn "Errore durante rimozione di $dir: @$err\n";
                }
            };
        }
    }
    
    # Rimuovi eventuali file di log dalla directory corrente
    for my $file (glob("download_log.txt")) {
        unlink $file if -f $file;
    }
}

# Crea una directory temporanea registrata
sub tempdir_cleanup {
    my %opts = @_;
    $opts{CLEANUP} = 1 unless exists $opts{CLEANUP};
    my $dir = tempdir(%opts);
    register_tempdir($dir);
    return $dir;
}

1;

