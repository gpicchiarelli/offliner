package OffLiner::Parser;

use strict;
use warnings;
use 5.014;
use HTML::LinkExtor;
use HTML::HeadParser;
use URI;
use Exporter 'import';

our $VERSION = '1.0.0';
our @EXPORT_OK = qw(get_encoding extract_links);

# Determina la codifica di una risposta HTTP
sub get_encoding {
    my ($response) = @_;
    
    # Prova a ottenere la codifica dall'header Content-Type
    my $content_type = $response->header('Content-Type');
    if ($content_type && $content_type =~ /charset=([^\s;]+)/i) {
        return $1;
    }
    
    # Prova a parsare l'HTML per trovare la codifica
    my $parser = HTML::HeadParser->new;
    eval {
        $parser->parse($response->content);
        my $meta_content_type = $parser->header('Content-Type');
        if ($meta_content_type && $meta_content_type =~ /charset=([^\s;]+)/i) {
            return $1;
        }
    };
    
    # Default a UTF-8 se non trovato
    return 'UTF-8';
}

# Estrae link da contenuto HTML
sub extract_links {
    my ($content, $base_url, $callback) = @_;
    
    # Ottimizzazione: cache URI locale (non condivisa tra thread per evitare problemi)
    # Nota: cache locale per chiamata, non globale per thread-safety
    my $base_uri = URI->new($base_url);
    
    my $base_host = $base_uri->host;
    return () unless $base_host;  # Early return se host non valido
    
    my @links = ();
    
    # Ottimizzazione: pre-compila regex per tag
    my $tag_re = qr/^(a|img|link|script|iframe|video|audio|source|object|embed|meta|track|form)$/;
    
    my $parser = HTML::LinkExtor->new(sub {
        my ($tag, %attr) = @_;
        
        # Lista di tag da controllare (pre-compilata)
        return unless $tag =~ $tag_re;
        
        # Estrazione link dai vari attributi (ottimizzata)
        my $link = $attr{href} || $attr{src} || $attr{data} || 
                   $attr{action} || $attr{poster} || 
                   ($tag eq 'meta' ? $attr{content} : undef);
        
        return unless $link;
        
        # Gestione di meta-refresh
        if ($tag eq 'meta' && $link =~ /URL=([^;]+)/i) {
            $link = $1;
        }
        
        # Ottimizzazione: check rapido prima di creare URI
        # Skip se non inizia con http/https o se è relativo e non valido
        return unless $link =~ /^https?:\/\// || $link =~ /^[\/\.]/;
        
        # Converti in URL assoluto
        my $abs_link;
        eval {
            $abs_link = URI->new_abs($link, $base_uri)->as_string;
        };
        return unless $abs_link && $abs_link =~ /^https?:\/\//;
        
        # Ottimizzazione: check host senza creare nuovo URI
        # Estrai host direttamente dalla stringa URL
        if ($abs_link =~ /^https?:\/\/([^\/]+)/) {
            my $link_host = $1;
            # Rimuovi porta se presente
            $link_host =~ s/:\d+$//;
            
            # Segui solo link dello stesso dominio
            if ($link_host eq $base_host) {
                push @links, $abs_link;
                $callback->($abs_link) if $callback;
            }
        }
    });
    
    eval {
        $parser->parse($content);
    };
    
    return @links;
}

1;

__END__

=head1 NAME

OffLiner::Parser - Parsing HTML e estrazione link

=head1 SYNOPSIS

    use OffLiner::Parser;
    
    my $encoding = OffLiner::Parser::get_encoding($response);
    my @links = OffLiner::Parser::extract_links($html_content, $base_url, $callback);

=head1 DESCRIPTION

Gestisce il parsing di HTML e l'estrazione di link da pagine web.

=head1 FUNCTIONS

=over 4

=item B<get_encoding($response)>

Determina la codifica di una risposta HTTP analizzando header e meta tag.

=item B<extract_links($content, $base_url, $callback)>

Estrae tutti i link da un contenuto HTML. Il callback viene chiamato per ogni link trovato.

=back

=cut

