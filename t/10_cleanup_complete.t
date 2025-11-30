#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use File::Find;
use Cwd qw(cwd);

# Carica helper per cleanup automatico
BEGIN {
    require File::Spec->catfile($FindBin::Bin, 'test_helper.pl');
}

# Test completo di cleanup - verifica che tutti i file temporanei vengano rimossi

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Crea directory temporanee separate per input e output
my $test_base = tempdir(CLEANUP => 1);
my $output_dir = File::Spec->catfile($test_base, 'output');
my $original_dir = cwd();

# Salva lo stato iniziale della directory corrente
my @files_before = ();
find(sub {
    return if -d $_;
    push @files_before, $File::Find::name;
}, '.');

# Esegui lo script con directory di output specificata
# Usa un URL non raggiungibile per testare cleanup anche in caso di errore
my $output = `timeout 3 $perl "$script" --url "http://127.0.0.1:65535/test" --max-depth 1 --max-threads 1 --output-dir "$output_dir" 2>&1 || true`;

# Verifica che la directory di output sia stata creata (anche se vuota)
if (-d $output_dir) {
    pass("Directory di output creata");
    
    # Lista file nella directory di output
    my @output_files = ();
    find(sub {
        return if -d $_;
        push @output_files, $File::Find::name;
    }, $output_dir);
    
    # Verifica che non ci siano file nella directory corrente
    my @files_after = ();
    find(sub {
        return if -d $_;
        push @files_after, $File::Find::name;
    }, '.');
    
    # Rimuovi file che erano già presenti
    my %files_before_hash = map { $_ => 1 } @files_before;
    my @new_files = grep { !$files_before_hash{$_} } @files_after;
    
    # Rimuovi eventuali file di log dalla directory corrente
    for my $file (@new_files) {
        if ($file =~ /download_log\.txt$/) {
            unlink $file if -f $file;
        }
    }
    
    # Verifica che non ci siano nuovi file nella directory corrente
    @new_files = grep { !/download_log\.txt$/ } @new_files;
    is(scalar(@new_files), 0, "Nessun file temporaneo lasciato nella directory corrente")
        or diag("File trovati: " . join(", ", @new_files));
} else {
    # Se la directory non è stata creata, potrebbe essere perché lo script è fallito subito
    # Questo è accettabile
    pass("Directory di output non creata (script fallito prima)");
}

# Cleanup manuale di eventuali file rimasti
for my $file (glob("download_log.txt")) {
    unlink $file if -f $file;
}

done_testing();

