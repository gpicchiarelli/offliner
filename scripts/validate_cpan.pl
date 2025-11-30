#!/usr/bin/env perl

=head1 NAME

validate_cpan.pl - Valida la distribuzione CPAN per OffLiner

=head1 SYNOPSIS

    perl scripts/validate_cpan.pl

=head1 DESCRIPTION

Valida che tutti i file necessari per la pubblicazione CPAN siano presenti
e corretti.

=cut

use strict;
use warnings;
use 5.010;
use File::Spec;
use File::Find;
use JSON::PP;

my $errors = 0;
my $warnings = 0;

print "Validating CPAN distribution...\n\n";

# Verifica file essenziali
my @required_files = qw(
    Makefile.PL
    META.json
    MANIFEST
    README.md
    LICENSE
    offliner.pl
);

print "Checking required files...\n";
for my $file (@required_files) {
    if (-f $file) {
        print "  ✓ $file\n";
    } else {
        print "  ✗ $file (MISSING)\n";
        $errors++;
    }
}

# Verifica META.json
print "\nValidating META.json...\n";
if (-f 'META.json') {
    eval {
        my $json = do {
            local $/;
            open my $fh, '<', 'META.json' or die "Cannot read META.json: $!\n";
            <$fh>;
        };
        my $meta = decode_json($json);
        
        # Verifica campi essenziali
        for my $field (qw(name version abstract author license)) {
            if (exists $meta->{$field}) {
                print "  ✓ $field: " . (ref $meta->{$field} ? join(', ', @{$meta->{$field}}) : $meta->{$field}) . "\n";
            } else {
                print "  ✗ $field (MISSING)\n";
                $errors++;
            }
        }
        
        # Verifica prereqs
        if (exists $meta->{prereqs} && exists $meta->{prereqs}->{runtime}) {
            my $count = keys %{$meta->{prereqs}->{runtime}->{requires} || {}};
            print "  ✓ runtime requires: $count modules\n";
        }
    };
    if ($@) {
        print "  ✗ META.json parse error: $@\n";
        $errors++;
    }
} else {
    print "  ✗ META.json not found\n";
    $errors++;
}

# Verifica MANIFEST
print "\nValidating MANIFEST...\n";
if (-f 'MANIFEST') {
    open my $fh, '<', 'MANIFEST' or die "Cannot read MANIFEST: $!\n";
    my @manifest = grep { !/^\s*#/ && /\S/ } <$fh>;
    close $fh;
    
    my $missing = 0;
    for my $line (@manifest) {
        chomp $line;
        $line =~ s/\s+.*$//;  # Rimuovi commenti
        next unless $line;
        
        unless (-f $line || -d $line) {
            print "  ⚠ $line (listed but not found)\n";
            $warnings++;
            $missing++;
        }
    }
    
    print "  ✓ MANIFEST contains " . scalar(@manifest) . " entries\n";
    if ($missing) {
        print "  ⚠ $missing files listed in MANIFEST but not found\n";
    }
} else {
    print "  ✗ MANIFEST not found\n";
    $errors++;
}

# Verifica test
print "\nChecking test files...\n";
my $test_count = 0;
if (-d 't') {
    opendir my $dh, 't' or die "Cannot read t/: $!\n";
    my @test_files = grep { /\.t$/ } readdir $dh;
    closedir $dh;
    $test_count = scalar(@test_files);
    print "  ✓ Found $test_count test files\n";
} else {
    print "  ⚠ t/ directory not found\n";
    $warnings++;
}

# Verifica sintassi
print "\nChecking syntax...\n";
if (-f 'offliner.pl') {
    system("perl -c offliner.pl > /dev/null 2>&1");
    if ($? == 0) {
        print "  ✓ offliner.pl syntax OK\n";
    } else {
        print "  ✗ offliner.pl syntax errors\n";
        $errors++;
    }
}

# Verifica Makefile.PL
print "\nChecking Makefile.PL...\n";
if (-f 'Makefile.PL') {
    system("perl -c Makefile.PL > /dev/null 2>&1");
    if ($? == 0) {
        print "  ✓ Makefile.PL syntax OK\n";
    } else {
        print "  ✗ Makefile.PL syntax errors\n";
        $errors++;
    }
}

# Riepilogo
print "\n" . "=" x 50 . "\n";
print "Validation Summary:\n";
print "  Errors:   $errors\n";
print "  Warnings: $warnings\n";

if ($errors == 0 && $warnings == 0) {
    print "\n✓ All validations passed! Ready for CPAN upload.\n";
    exit 0;
} elsif ($errors == 0) {
    print "\n⚠ Validation passed with warnings. Review before uploading.\n";
    exit 0;
} else {
    print "\n✗ Validation failed. Fix errors before uploading.\n";
    exit 1;
}

