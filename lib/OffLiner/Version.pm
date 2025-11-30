package OffLiner::Version;

use strict;
use warnings;
use 5.014;
use LWP::UserAgent;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(version_compare check_for_updates);

# Confronta due versioni
sub version_compare {
    my ($v1, $v2) = @_;
    my @v1_parts = split /\./, $v1;
    my @v2_parts = split /\./, $v2;
    
    for my $i (0..$#v1_parts) {
        my $p1 = $v1_parts[$i] || 0;
        my $p2 = $v2_parts[$i] || 0;
        return 1 if $p1 > $p2;
        return -1 if $p1 < $p2;
    }
    
    return 0;
}

# Verifica aggiornamenti disponibili
sub check_for_updates {
    my ($current_version, $verbose) = @_;
    $verbose //= 0;
    
    eval {
        my $ua = LWP::UserAgent->new(timeout => 5);
        $ua->agent("OffLiner/$current_version");
        
        my $response = $ua->get('https://api.github.com/repos/gpicchiarelli/offliner/releases/latest');
        
        if ($response->is_success) {
            my $content = $response->decoded_content;
            if ($content =~ /"tag_name"\s*:\s*"v?([\d.]+)"/) {
                my $latest_version = $1;
                if (version_compare($latest_version, $current_version) > 0) {
                    print "📦 Nuova versione disponibile: $latest_version (attuale: $current_version)\n";
                    print "Scarica da: https://github.com/gpicchiarelli/offliner/releases/latest\n";
                    return $latest_version;
                } else {
                    print "✓ Sei aggiornato alla versione $current_version\n";
                    return undef;
                }
            }
        }
    };
    
    if ($@) {
        warn "Impossibile verificare aggiornamenti: $@\n" if $verbose;
    }
    
    return undef;
}

1;

__END__

=encoding UTF-8

=head1 NAME

OffLiner::Version - Gestione versioni e aggiornamenti

=head1 SYNOPSIS

    use OffLiner::Version;

    my $cmp = OffLiner::Version::version_compare('1.0.0', '1.0.1');
    my $latest = OffLiner::Version::check_for_updates($current_version, $verbose);

=head1 DESCRIPTION

Gestisce il confronto di versioni e la verifica di aggiornamenti disponibili.

=head1 FUNCTIONS

=over 4

=item B<version_compare($v1, $v2)>

Confronta due versioni. Ritorna 1 se v1 > v2, -1 se v1 < v2, 0 se uguali.

=item B<check_for_updates($current_version, $verbose)>

Verifica se ci sono aggiornamenti disponibili su GitHub.

=back

=cut

