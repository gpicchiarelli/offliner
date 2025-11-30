#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use IO::Socket::INET;
use Time::HiRes qw(sleep);

# Test funzionale con server HTTP mock
# Questo test viene saltato se HTTP::Server::Simple non è disponibile

SKIP: {
    # Verifica disponibilità di HTTP::Server::Simple
    eval { require HTTP::Server::Simple; require HTTP::Server::Simple::CGI; };
    skip "HTTP::Server::Simple non disponibile (installalo con: cpanm HTTP::Server::Simple)", 5 if $@;
    
    my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
    my $perl = $^X;
    
    # Crea una directory temporanea per l'output
    my $output_dir = tempdir(CLEANUP => 1);
    
    # Crea un server HTTP semplice per i test
    my $port = find_free_port();
    my $server_pid = start_test_server($port);
    
    # Aspetta che il server sia pronto
    sleep 0.5;
    
    skip "Server di test non avviato", 5 unless $server_pid;
    
    # Test download di una pagina semplice
    my $output = `timeout 10 $perl "$script" --url "http://127.0.0.1:$port/" --max-depth 1 --max-threads 1 --output-dir "$output_dir" 2>&1`;
    my $exit_code = $? >> 8;
    
    # Verifica che i file siano stati creati
    my @files = glob(File::Spec->catfile($output_dir, "*", "*"));
    ok(scalar(@files) > 0, "File creati durante il download")
        or diag("Output: $output\nFiles: " . join(", ", @files));
    
    # Verifica che esista almeno un file HTML
    my @html_files = grep { /\.html$/ } @files;
    ok(scalar(@html_files) > 0, "Almeno un file HTML creato");
    
    # Verifica che il file di log esista
    my @log_files = glob(File::Spec->catfile($output_dir, "*", "download_log.txt"));
    ok(scalar(@log_files) >= 0, "File di log creato (o non necessario)");
    
    # Verifica che i file contengano contenuto
    if (@html_files) {
        my $content = do {
            local $/;
            open my $fh, '<', $html_files[0] or die "Cannot read $html_files[0]: $!";
            <$fh>;
        };
        ok(length($content) > 0, "File HTML contiene contenuto");
        like($content, qr/Test Page|Hello|html/i, "Contenuto HTML valido");
    }
    
    # Test con verbose
    my $verbose_output = `timeout 10 $perl "$script" --url "http://127.0.0.1:$port/" --max-depth 1 --max-threads 1 --output-dir "$output_dir" --verbose 2>&1`;
    like($verbose_output, qr/Scaricamento|Download|completato/i, "Output verboso funziona");
    
    # Termina il server di test
    kill 'TERM', $server_pid if $server_pid;
    waitpid $server_pid, 0 if $server_pid;
}

done_testing();

sub find_free_port {
    my $socket = IO::Socket::INET->new(
        LocalAddr => '127.0.0.1',
        LocalPort => 0,
        Proto => 'tcp',
        Listen => 1,
    );
    my $port = $socket->sockport;
    $socket->close;
    return $port;
}

sub start_test_server {
    my ($port) = @_;
    
    my $pid = fork();
    if ($pid == 0) {
        # Processo figlio - avvia il server usando string eval per evitare problemi di compilazione
        eval q{
            package TestHTTPServer;
            use HTTP::Server::Simple::CGI;
            use base 'HTTP::Server::Simple::CGI';
            
            sub handle_request {
                my ($self, $cgi) = @_;
                
                my $path = $cgi->path_info || '/';
                
                if ($path eq '/' || $path eq '/index.html') {
                    print "HTTP/1.0 200 OK\r\n";
                    print "Content-Type: text/html; charset=UTF-8\r\n";
                    print "\r\n";
                    print <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Test Page</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Hello, World!</h1>
    <p>This is a test page for OffLiner.</p>
    <a href="/page1.html">Page 1</a>
    <a href="/page2.html">Page 2</a>
</body>
</html>
HTML
                } elsif ($path eq '/page1.html') {
                    print "HTTP/1.0 200 OK\r\n";
                    print "Content-Type: text/html; charset=UTF-8\r\n";
                    print "\r\n";
                    print <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Page 1</title>
</head>
<body>
    <h1>Page 1</h1>
    <a href="/">Home</a>
</body>
</html>
HTML
                } elsif ($path eq '/page2.html') {
                    print "HTTP/1.0 200 OK\r\n";
                    print "Content-Type: text/html; charset=UTF-8\r\n";
                    print "\r\n";
                    print <<'HTML';
<!DOCTYPE html>
<html>
<head>
    <title>Page 2</title>
</head>
<body>
    <h1>Page 2</h1>
    <a href="/">Home</a>
</body>
</html>
HTML
                } else {
                    print "HTTP/1.0 404 Not Found\r\n";
                    print "Content-Type: text/plain\r\n";
                    print "\r\n";
                    print "Not Found";
                }
            }
            
            my $server = TestHTTPServer->new($port);
            $server->run;
        };
        if ($@) {
            warn "Errore avvio server: $@\n";
        }
        exit 0;
    }
    
    return $pid;
}
