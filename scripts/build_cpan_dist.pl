#!/usr/bin/env perl

=head1 NAME

build_cpan_dist.pl - Crea la distribuzione CPAN per OffLiner

=head1 SYNOPSIS

    perl scripts/build_cpan_dist.pl [--test]

=head1 DESCRIPTION

Crea una distribuzione CPAN pronta per la pubblicazione, inclusa la validazione
di tutti i file necessari.

=cut

use strict;
use warnings;
use 5.010;
use File::Spec;
use File::Path qw(rmtree make_path);
use File::Find;
use Cwd qw(cwd);

my $test_only = grep { $_ eq '--test' } @ARGV;

# Verifica che siamo nella directory root del progetto
my $script_dir = File::Spec->rel2abs(__FILE__);
$script_dir =~ s/scripts\/build_cpan_dist\.pl$//;
chdir $script_dir or die "Cannot chdir to $script_dir: $!\n";

print "Building CPAN distribution for OffLiner...\n\n";

# Verifica prerequisiti
print "Checking prerequisites...\n";
for my $cmd (qw(perl make)) {
    system("which $cmd > /dev/null 2>&1");
    die "Error: $cmd not found\n" if $? != 0;
}

# Verifica che Makefile.PL esista
die "Error: Makefile.PL not found\n" unless -f 'Makefile.PL';

# Pulisci build precedenti
print "Cleaning previous builds...\n";
for my $dir (qw(blib _eumm)) {
    rmtree($dir) if -d $dir;
}
unlink 'Makefile' if -f 'Makefile';
unlink 'Makefile.old' if -f 'Makefile.old';

# Genera Makefile
print "Generating Makefile...\n";
system("perl Makefile.PL");
die "Error: Makefile.PL failed\n" if $? != 0;

# Verifica sintassi
print "Checking syntax...\n";
system("perl -c offliner.pl");
die "Error: Syntax check failed\n" if $? != 0;

# Esegui test
if ($test_only || !grep { $_ eq '--skip-tests' } @ARGV) {
    print "Running tests...\n";
    system("make test");
    die "Error: Tests failed\n" if $? != 0;
    print "All tests passed!\n\n";
}

# Crea MANIFEST se non esiste o aggiornalo
print "Updating MANIFEST...\n";
system("make manifest");
die "Error: make manifest failed\n" if $? != 0;

# Verifica MANIFEST
print "Verifying MANIFEST...\n";
if (-f 'MANIFEST') {
    open my $fh, '<', 'MANIFEST' or die "Cannot read MANIFEST: $!\n";
    my @manifest_files = grep { !/^\s*#/ && /\S/ } <$fh>;
    close $fh;
    print "MANIFEST contains " . scalar(@manifest_files) . " files\n";
} else {
    die "Error: MANIFEST not created\n";
}

# Crea distdir
print "Creating distribution directory...\n";
system("make distdir");
die "Error: make distdir failed\n" if $? != 0;

# Trova la directory di distribuzione
my $dist_dir;
opendir my $dh, '.' or die "Cannot read directory: $!\n";
for my $file (readdir $dh) {
    if ($file =~ /^OffLiner-[\d.]+$/) {
        $dist_dir = $file;
        last;
    }
}
closedir $dh;

die "Error: Distribution directory not found\n" unless $dist_dir && -d $dist_dir;

print "\nDistribution directory created: $dist_dir\n";

# Crea tarball
print "Creating tarball...\n";
system("make dist");
die "Error: make dist failed\n" if $? != 0;

# Trova il tarball
my $tarball;
opendir $dh, '.' or die "Cannot read directory: $!\n";
for my $file (readdir $dh) {
    if ($file =~ /^OffLiner-[\d.]+\.tar\.gz$/) {
        $tarball = $file;
        last;
    }
}
closedir $dh;

if ($tarball && -f $tarball) {
    my $size = -s $tarball;
    print "\n✓ Distribution tarball created: $tarball (" . sprintf("%.2f", $size/1024) . " KB)\n";
    print "\nTo upload to CPAN, use:\n";
    print "  cpan-upload $tarball\n";
    print "\nOr use the GitHub Actions workflow for automatic upload.\n";
} else {
    die "Error: Tarball not created\n";
}

# Validazione finale
print "\nValidating distribution...\n";
system("tar -tzf $tarball > /dev/null 2>&1");
if ($? == 0) {
    print "✓ Tarball is valid\n";
} else {
    warn "Warning: Tarball validation failed\n";
}

print "\n✓ CPAN distribution build completed successfully!\n";

