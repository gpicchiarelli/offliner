#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use FindBin qw($Bin);

# Test che tutti i moduli richiesti siano disponibili
my @required_modules = qw(
    LWP::UserAgent
    URI
    File::Path
    File::Basename
    Getopt::Long
    Time::Piece
    Time::HiRes
    threads
    Thread::Queue
    threads::shared
    Thread::Semaphore
    Encode
    HTML::LinkExtor
    HTML::HeadParser
    IO::Socket::SSL
    Mozilla::CA
    FindBin
);

# Test moduli OffLiner
my @offliner_modules = qw(
    OffLiner::Config
    OffLiner::Utils
    OffLiner::Logger
    OffLiner::Downloader
    OffLiner::Parser
    OffLiner::Worker
    OffLiner::Stats
    OffLiner::Version
);

plan tests => scalar(@required_modules) + scalar(@offliner_modules);

foreach my $module (@required_modules) {
    eval "require $module";
    ok(!$@, "Modulo $module disponibile") or diag("Errore: $@");
}

# Test moduli OffLiner
use FindBin qw($Bin);
use lib "$Bin/../lib";

foreach my $module (@offliner_modules) {
    eval "require $module";
    ok(!$@, "Modulo $module disponibile") or diag("Errore: $@");
}

done_testing();

