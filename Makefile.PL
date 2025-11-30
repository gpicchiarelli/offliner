use 5.014;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'OffLiner',
    VERSION_FROM        => 'offliner.pl',
    ABSTRACT            => 'Scaricatore di siti web offline',
    AUTHOR              => 'Giacomo Picchiarelli',
    LICENSE             => 'bsd',
    MIN_PERL_VERSION    => '5.014',
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
        'JSON::PP'            => '2.00',
        'FindBin'             => 0,
    },
    EXE_FILES           => ['offliner.pl'],
    test => {
        TESTS => 't/*.t',
        RECURSIVE_TEST_FILES => 1,
    },
    # BUILD_REQUIRES è supportato da Perl 5.10+, TEST_REQUIRES solo da 5.14+
    # Usiamo BUILD_REQUIRES per compatibilità con versioni più vecchie di MakeMaker
    BUILD_REQUIRES => {
        'Test::More'          => '0.88',
        'File::Temp'          => '0.22',
        'File::Spec'          => '3.40',
        'FindBin'             => 0,
        'Cwd'                 => 0,
        'File::Find'          => 0,
        'Time::HiRes'         => 0,
        'IO::Socket::INET'    => 0,
    },
    # Test opzionali per POD e qualità codice
    TEST_REQUIRES => {
        'Test::Pod'           => '1.48',
        'Test::Pod::Coverage' => '1.08',
        'Perl::Critic'        => '1.126',
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
            homepage => 'https://github.com/gpicchiarelli/offliner',
        },
        keywords => [qw(offline download website crawler wget archive)],
        'x_contributors' => ['Giacomo Picchiarelli'],
    },
    dist => {
        COMPRESS => 'gzip -9f',
        SUFFIX => 'gz',
        PREOP => '$(MAKE) -f Makefile.old distdir',
        POSTOP => 'rm -rf $(DISTVNAME)/.git',
    },
);


