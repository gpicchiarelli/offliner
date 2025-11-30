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
ok(-x $script || $^O eq 'MSWin32', "Script offliner.pl è eseguibile (o su Windows)");

done_testing();
