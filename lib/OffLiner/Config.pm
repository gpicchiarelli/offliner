package OffLiner::Config;

use strict;
use warnings;
use 5.014;
use JSON::PP qw(decode_json);
use File::Spec;

our $VERSION = '1.0.0';

# Costanti di default
use constant DEFAULT_MAX_DEPTH   => 50;
use constant DEFAULT_MAX_THREADS => 10;
use constant DEFAULT_MAX_RETRIES => 3;
use constant DEFAULT_TIMEOUT     => 30;
use constant DEFAULT_USER_AGENT  => 'Mozilla/5.0 (compatible; OffLinerBot/1.0)';

use Exporter 'import';
our @EXPORT_OK = qw(load_config validate_params);
our %EXPORT_TAGS = (
    all => [qw(load_config validate_params)],
);

# Carica configurazione da file
sub load_config {
    my ($config_file) = @_;
    $config_file ||= $ENV{HOME} . '/.config/offliner/config.json';
    
    my %config = ();
    
    if (-f $config_file && -r $config_file) {
        eval {
            open my $fh, '<', $config_file or die "Cannot read config: $!";
            local $/;
            my $json = <$fh>;
            close $fh;
            my $data = decode_json($json);
            %config = %$data;
        };
        if ($@) {
            warn "[!] Errore lettura config: $@\n" if $ENV{VERBOSE};
        }
    }
    
    return %config;
}

# Valida parametri di configurazione
sub validate_params {
    my (%params) = @_;
    
    if (exists $params{max_depth} && $params{max_depth} < 0) {
        die "Errore: --max-depth deve essere >= 0\n";
    }
    if (exists $params{max_threads} && $params{max_threads} < 1) {
        die "Errore: --max-threads deve essere >= 1\n";
    }
    if (exists $params{max_retries} && $params{max_retries} < 1) {
        die "Errore: --max-retries deve essere >= 1\n";
    }
    
    return 1;
}

1;

__END__

=head1 NAME

OffLiner::Config - Gestione configurazione per OffLiner

=head1 SYNOPSIS

    use OffLiner::Config;
    
    my %config = OffLiner::Config::load_config();
    my $max_depth = $config{default_max_depth} // OffLiner::Config::DEFAULT_MAX_DEPTH;

=head1 DESCRIPTION

Gestisce il caricamento e la validazione della configurazione per OffLiner.

=head1 FUNCTIONS

=over 4

=item B<load_config($config_file)>

Carica la configurazione da un file JSON. Se non specificato, usa 
~/.config/offliner/config.json.

=item B<validate_params(%params)>

Valida i parametri di configurazione e lancia eccezioni se non validi.

=back

=head1 CONSTANTS

=over 4

=item DEFAULT_MAX_DEPTH

Profondità massima di default (50)

=item DEFAULT_MAX_THREADS

Numero massimo di thread di default (10)

=item DEFAULT_MAX_RETRIES

Numero massimo di retry di default (3)

=item DEFAULT_TIMEOUT

Timeout di default in secondi (30)

=item DEFAULT_USER_AGENT

User-Agent di default

=back

=cut

