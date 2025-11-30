#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# Test POD documentation coverage
plan tests => 2;

# Test che Test::Pod sia disponibile
SKIP: {
    eval { require Test::Pod; };
    skip "Test::Pod non disponibile (installalo con: cpanm Test::Pod)", 1 if $@;
    
    # Test POD per tutti i moduli
    my @modules = qw(
        OffLiner::Config
        OffLiner::Downloader
        OffLiner::Logger
        OffLiner::Parser
        OffLiner::Utils
        OffLiner::Version
        OffLiner::Worker
        OffLiner::Stats
        OffLiner::Platform::macOS
    );
    
    my $pod_tests = 0;
    for my $module (@modules) {
        my $file = $module;
        $file =~ s/::/\//g;
        $file = "$Bin/../lib/$file.pm";
        if (-f $file) {
            Test::Pod::pod_file_ok($file, "POD valido per $module");
            $pod_tests++;
        }
    }
    
    ok($pod_tests > 0, "Almeno un modulo ha POD valido");
}

# Test POD coverage (opzionale, richiede Test::Pod::Coverage)
SKIP: {
    eval { require Test::Pod::Coverage; };
    skip "Test::Pod::Coverage non disponibile (installalo con: cpanm Test::Pod::Coverage)", 1 if $@;
    
    # Test coverage POD per tutti i moduli
    my @modules = qw(
        OffLiner::Config
        OffLiner::Downloader
        OffLiner::Logger
        OffLiner::Parser
        OffLiner::Utils
        OffLiner::Version
        OffLiner::Worker
        OffLiner::Stats
        OffLiner::Platform::macOS
    );
    
    for my $module (@modules) {
        Test::Pod::Coverage::pod_coverage_ok($module, "POD coverage per $module");
    }
    
    pass("POD coverage test completato");
}

done_testing();

