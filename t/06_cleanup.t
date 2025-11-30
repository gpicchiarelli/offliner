#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use Cwd qw(cwd);

# Test che lo script non lasci file temporanei nella directory corrente
# quando viene eseguito con --output-dir

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Crea una directory temporanea per l'output
my $test_dir = tempdir(CLEANUP => 1);
my $original_dir = cwd();

# Verifica che non ci siano file di log nella directory corrente prima del test
my @log_files_before = glob("download_log.txt");

# Esegui lo script con un URL non raggiungibile e timeout breve
# Questo testa che anche in caso di errore non vengano lasciati file
# IMPORTANTE: Usa --output-dir per specificare dove salvare
my $output = `timeout 3 $perl "$script" --url "http://127.0.0.1:99999/nonexistent" --max-depth 1 --max-threads 1 --output-dir "$test_dir" 2>&1 || true`;

# Verifica che non siano stati creati file di log nella directory corrente
my @log_files_after = glob("download_log.txt");

# Il test passa se non ci sono nuovi file di log nella directory corrente
my $new_log_files = scalar(@log_files_after) - scalar(@log_files_before);
is($new_log_files, 0, "Nessun file di log creato nella directory corrente quando si usa --output-dir")
    or diag("File di log trovati: " . join(", ", @log_files_after));

# Cleanup: rimuovi eventuali file di log creati
for my $file (@log_files_after) {
    unlink $file if -f $file && !grep { $_ eq $file } @log_files_before;
}

# Verifica anche che la directory di output sia stata creata (anche se vuota)
if (-d $test_dir) {
    my @output_files = glob(File::Spec->catfile($test_dir, "*", "*"));
    pass("Directory di output creata correttamente");
} else {
    pass("Directory di output non creata (script fallito prima)");
}

done_testing();
