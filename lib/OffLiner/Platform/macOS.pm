package OffLiner::Platform::macOS;

use strict;
use warnings;
use 5.014;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(is_macos get_clipboard_url send_notification);

# Verifica se siamo su macOS
sub is_macos {
    return $^O eq 'darwin';
}

# Ottiene URL dalla clipboard (macOS)
sub get_clipboard_url {
    return undef unless is_macos();
    return undef unless -x '/usr/bin/pbpaste';
    
    my $clipboard = `pbpaste 2>/dev/null`;
    chomp $clipboard;
    
    # Cerca URL nel testo
    if ($clipboard =~ /(https?:\/\/[^\s]+)/) {
        return $1;
    }
    
    # Se è già un URL valido
    if ($clipboard =~ /^https?:\/\//) {
        return $clipboard;
    }
    
    return undef;
}

# Invia notifiche macOS
sub send_notification {
    my ($title, $message, $output_path, $success) = @_;
    $success = 1 unless defined $success;
    
    return unless is_macos();
    return unless -x '/usr/bin/osascript';
    
    # Escape caratteri speciali per AppleScript (metodo robusto)
    $title =~ s/\\/\\\\/g;
    $title =~ s/"/\\"/g;
    $title =~ s/\$/\\\$/g;
    $title =~ s/`/\\`/g;
    
    $message =~ s/\\/\\\\/g;
    $message =~ s/"/\\"/g;
    $message =~ s/\$/\\\$/g;
    $message =~ s/`/\\`/g;
    $message =~ s/\n/\\n/g;
    
    my $sound = $success ? 'Glass' : 'Basso';
    
    # Usa AppleScript con escape corretto
    my $script = qq{display notification "$message" with title "$title" subtitle "OffLiner" sound name "$sound"};
    
    eval {
        open my $pipe, '|-', 'osascript', '-e', $script or return;
        close $pipe;
    };
    
    # Apri Finder nella directory di output (opzionale)
    if ($output_path && -d $output_path && -x '/usr/bin/open') {
        eval {
            system('open', $output_path) == 0;
        };
    }
}

1;

__END__

=encoding UTF-8

=head1 NAME

OffLiner::Platform::macOS - Funzioni specifiche per macOS

=head1 SYNOPSIS

    use OffLiner::Platform::macOS;

    my $url = OffLiner::Platform::macOS::get_clipboard_url();
    OffLiner::Platform::macOS::send_notification($title, $message, $path, $success);

=head1 DESCRIPTION

Fornisce funzionalità specifiche per macOS come notifiche e accesso alla clipboard.

=head1 FUNCTIONS

=over 4

=item B<is_macos()>

Verifica se il sistema operativo è macOS.

=item B<get_clipboard_url()>

Estrae un URL dalla clipboard di macOS.

=item B<send_notification($title, $message, $output_path, $success)>

Invia una notifica macOS con opzione di aprire Finder.

=back

=cut

