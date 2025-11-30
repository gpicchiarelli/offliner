package OffLiner::Logger;

use strict;
use warnings;
use 5.014;
use Time::Piece;
use File::Spec;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(init log_error verbose info);

# Logger singleton
my $log_file;
my $verbose = 0;

# Inizializza il logger
sub init {
    my ($file, $verb) = @_;
    $log_file = $file;
    $verbose = $verb // 0;
}

# Registra un errore nel file di log
sub log_error {
    my ($message) = @_;
    return unless $log_file;
    
    my $timestamp = localtime->strftime('%Y-%m-%d %H:%M:%S');
    eval {
        open my $log_fh, '>>:encoding(UTF-8)', $log_file;
        print $log_fh "[$timestamp] $message\n";
        close $log_fh;
    };
    # Ignora errori di scrittura del log per non interrompere l'esecuzione
}

# Log verboso
sub verbose {
    my ($message) = @_;
    print $message if $verbose;
}

# Log standard
sub info {
    my ($message) = @_;
    print $message;
}

1;

__END__

=head1 NAME

OffLiner::Logger - Sistema di logging per OffLiner

=head1 SYNOPSIS

    use OffLiner::Logger;
    
    OffLiner::Logger::init($log_file, $verbose);
    OffLiner::Logger::log_error("Errore durante il download");
    OffLiner::Logger::verbose("[+] Scaricamento: $url\n");
    OffLiner::Logger::info("[+] Download completato\n");

=head1 DESCRIPTION

Gestisce il logging degli errori e dei messaggi informativi.

=head1 FUNCTIONS

=over 4

=item B<init($log_file, $verbose)>

Inizializza il logger con il file di log e il flag verbose.

=item B<log_error($message)>

Registra un errore nel file di log con timestamp.

=item B<verbose($message)>

Stampa un messaggio solo se verbose è abilitato.

=item B<info($message)>

Stampa un messaggio informativo.

=back

=cut

