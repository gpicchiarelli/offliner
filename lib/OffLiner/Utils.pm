package OffLiner::Utils;

use strict;
use warnings;
use 5.014;
use URI;
use File::Spec;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(get_site_title sanitize_filename uri_to_path validate_url);

# Ottiene il titolo del sito dall'URL
sub get_site_title {
    my ($url) = @_;
    my $uri = URI->new($url);
    my $host = $uri->host || 'unknown';
    $host =~ s/^www\.//;
    return $host;
}

# Sanifica il nome del file/directory
sub sanitize_filename {
    my ($filename) = @_;
    $filename =~ s/[^a-zA-Z0-9._-]/_/g;
    $filename =~ s/_+/_/g;
    $filename =~ s/^_|_$//g;
    return $filename || 'download';
}

# Converte un URL in un percorso di file
sub uri_to_path {
    my ($uri, $is_html) = @_;
    
    my $u = URI->new($uri);
    my $path = $u->path || '/';
    $path =~ s{^/}{};
    $path =~ s{/$}{/index} if $path;
    $path ||= 'index';
    
    # Rimuovi caratteri problematici
    $path =~ s/[^\w\.\-\/]/_/g;
    $path =~ s{/+}{/}g;
    
    # Aggiungi estensione se necessario
    unless ($path =~ /\.[a-z]{2,4}$/i) {
        $path .= $is_html ? '.html' : '';
    }
    
    return $path;
}

# Valida un URL
sub validate_url {
    my ($url) = @_;
    
    my $uri = URI->new($url);
    unless ($uri->scheme && ($uri->scheme eq 'http' || $uri->scheme eq 'https')) {
        return 0;
    }
    
    return 1;
}

1;

__END__

=head1 NAME

OffLiner::Utils - Funzioni utility per OffLiner

=head1 SYNOPSIS

    use OffLiner::Utils;
    
    my $title = OffLiner::Utils::get_site_title('https://example.com');
    my $path = OffLiner::Utils::uri_to_path($url, 1);
    my $clean = OffLiner::Utils::sanitize_filename('test file.html');

=head1 DESCRIPTION

Fornisce funzioni utility per la manipolazione di URL, nomi file e altre operazioni comuni.

=head1 FUNCTIONS

=over 4

=item B<get_site_title($url)>

Estrae il titolo del sito dall'URL (hostname senza www).

=item B<sanitize_filename($filename)>

Sanifica un nome di file rimuovendo caratteri problematici.

=item B<uri_to_path($uri, $is_html)>

Converte un URL in un percorso di file relativo.

=item B<validate_url($url)>

Valida che un URL sia valido (http:// o https://).

=back

=cut

