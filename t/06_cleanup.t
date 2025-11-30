#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use File::Path qw(rmtree);
use File::Find;

# Carica helper per cleanup automatico
BEGIN {
    require File::Spec->catfile($FindBin::Bin, 'test_helper.pl');
}

# Test che lo script non lasci file temporanei nella directory corrente
# quando viene eseguito con --output-dir

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Crea una directory temporanea per i test
my $test_dir = tempdir(CLEANUP => 1);
my $original_dir = cwd();

# Cambia nella directory temporanea per il test
chdir $test_dir or die "Impossibile cambiare directory: $!";

# Lista dei file prima del test
my @files_before = glob("*");

# Esegui lo script con un URL non raggiungibile e timeout breve
# Questo testa che anche in caso di errore non vengano lasciati file
my $output = `timeout 3 $perl "$script" --url "http://127.0.0.1:99999/nonexistent" --max-depth 1 --max-threads 1 --output-dir "$test_dir" 2>&1 || true`;

# Torna alla directory originale
chdir $original_dir or die "Impossibile tornare alla directory originale: $!";

# Lista dei file dopo il test (nella directory originale)
my @files_after = glob("*");

# Verifica che non siano stati creati file nella directory originale
# (escludendo file che potrebbero essere stati creati da altri processi)
my %files_before = map { $_ => 1 } @files_before;
my @new_files = grep { !$files_before{$_} } @files_after;

# Rimuovi file di log se creati nella directory corrente
for my $file (@new_files) {
    if ($file =~ /download_log\.txt$/) {
        unlink $file if -f $file;
    }
}

# Il test passa se non ci sono nuovi file (o solo file di log che abbiamo rimosso)
ok(scalar(@new_files) == 0 || (scalar(@new_files) == 1 && $new_files[0] =~ /download_log\.txt$/),
   "Nessun file temporaneo lasciato nella directory corrente")
    or diag("File trovati: " . join(", ", @new_files));

# Cleanup finale
for my $file (@new_files) {
    unlink $file if -f $file;
}

done_testing();

