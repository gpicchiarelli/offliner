use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OffLiner',
    VERSION_FROM        => 'offliner.pl',
    ABSTRACT_FROM       => 'offliner.pl',
    AUTHOR              => 'Giacomo Picchiarelli',
    LICENSE             => 'bsd',
    MIN_PERL_VERSION    => '5.010',
    PREREQ_PM => {
        'LWP::UserAgent'     => '6.00',
        'URI'                => '1.60',
        'File::Path'         => '2.00',
        'File::Basename'     => 0,
        'Getopt::Long'       => '2.30',
        'Time::Piece'        => '1.20',
        'threads'             => '1.83',
        'Thread::Queue'       => '3.00',
        'threads::shared'     => '1.40',
        'Thread::Semaphore'   => '2.10',
        'Encode'              => '2.00',
        'HTML::LinkExtor'     => '1.00',
        'HTML::HeadParser'    => '3.60',
        'IO::Socket::SSL'     => '2.000',
        'Mozilla::CA'         => '20160104',
        'FindBin'             => 0,
    },
    EXE_FILES           => ['offliner.pl'],
    test => {
        TESTS => 't/*.t',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/gpicchiarelli/offliner.git',
                web  => 'https://github.com/gpicchiarelli/offliner',
            },
            bugtracker => {
                web => 'https://github.com/gpicchiarelli/offliner/issues',
            },
        },
    },
);


