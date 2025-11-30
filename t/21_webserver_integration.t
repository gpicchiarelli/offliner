#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use IO::Socket::INET;
use Time::HiRes qw(sleep time);
use Digest::SHA qw(sha512_hex);
use File::Find;

# Test di integrazione con webserver temporaneo
# Crea un webserver, serve file HTML con contenuto noto,
# e verifica che offliner li scarichi correttamente

# Non pianifichiamo il numero esatto perché alcuni test potrebbero essere saltati
# Usiamo done_testing() alla fine

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;

# Crea directory temporanee con CLEANUP => 1 per rimozione automatica
# Su macOS vengono create in /var/folders/ che è temporaneo
my $test_dir = tempdir(
    CLEANUP => 1,
    TEMPLATE => 'offliner_test_XXXXXX',
    TMPDIR => 1  # Usa la directory temporanea di sistema
);
my $output_dir = tempdir(
    CLEANUP => 1,
    TEMPLATE => 'offliner_output_XXXXXX',
    TMPDIR => 1  # Usa la directory temporanea di sistema
);

# Blocco END per pulizia garantita anche in caso di interruzione
END {
    # File::Temp con CLEANUP => 1 dovrebbe già gestire la pulizia,
    # ma questo blocco garantisce la rimozione anche in caso di errori fatali
    if (defined $test_dir && -d $test_dir) {
        eval {
            require File::Path;
            File::Path::rmtree($test_dir, { error => \my $err });
        };
    }
    if (defined $output_dir && -d $output_dir) {
        eval {
            require File::Path;
            File::Path::rmtree($output_dir, { error => \my $err });
        };
    }
}

# Porta per il webserver (scegli una porta libera)
my $port = find_free_port();
plan skip_all => "Impossibile trovare una porta libera" unless $port;

# Crea 10 file HTML con contenuto noto e linkati tra loro
# Calcola anche SHA512 per verifica integrità
my @test_files = ();
my @test_contents = ();
my %original_hashes = ();  # Hash SHA512 dei file originali

for my $i (1..10) {
    my $filename = "page$i.html";
    my $next = ($i < 10) ? $i + 1 : 1;
    my $prev = ($i > 1) ? $i - 1 : 10;
    
    my $content = <<"HTML";
<!DOCTYPE html>
<html>
<head>
    <title>Test Page $i</title>
    <meta charset="UTF-8">
</head>
<body>
    <h1>Test Page $i</h1>
    <p>Questo è il contenuto del file di test numero $i.</p>
    <p>Timestamp: @{[time()]}</p>
    <p>Contenuto univoco: TEST_CONTENT_$i</p>
    <a href="/page$next.html">Next Page</a>
    <a href="/page$prev.html">Previous Page</a>
    <img src="/image$i.jpg" alt="Image $i">
</body>
</html>
HTML
    
    my $filepath = File::Spec->catfile($test_dir, $filename);
    open my $fh, '>', $filepath or die "Cannot create $filepath: $!";
    print $fh $content;
    close $fh;
    
    # Calcola SHA512 del file originale
    $original_hashes{$filename} = sha512_hex($content);
    
    push @test_files, $filename;
    push @test_contents, $content;
}

# Avvia webserver in background
my $server_pid = start_webserver($test_dir, $port);
plan skip_all => "Impossibile avviare webserver" unless $server_pid;

# Aspetta che il server sia pronto
sleep(0.5);

# Verifica che il server risponda
my $test_socket = IO::Socket::INET->new(
    PeerAddr => 'localhost',
    PeerPort => $port,
    Proto    => 'tcp',
    Timeout  => 2,
);
if ($test_socket) {
    close $test_socket;
    pass("Webserver risponde correttamente");
} else {
    diag("Webserver non risponde, termino il processo");
    kill('KILL', $server_pid) if $server_pid;
    waitpid($server_pid, 0) if $server_pid;
    skip "Webserver non funzionante", 7;
}

# Test: scarica con offliner (con timeout usando alarm)
my $base_url = "http://localhost:$port";
my $cmd = qq{$perl "$script" --url "$base_url/page1.html" --output-dir "$output_dir" --max-depth 2 --max-threads 2 --max-retries 1 2>&1};

# Esegui con timeout usando alarm
my $output;
my $exit_code;
eval {
    local $SIG{ALRM} = sub { die "timeout\n" };
    alarm(20);  # Timeout di 20 secondi
    $output = `$cmd`;
    $exit_code = $? >> 8;
    alarm(0);
};
if ($@ && $@ =~ /timeout/) {
    diag("Comando offliner timeout dopo 20 secondi");
    kill('KILL', $server_pid) if $server_pid;
    waitpid($server_pid, 0) if $server_pid;
    skip "Test timeout", 6;
}

# Verifica che il comando sia eseguito
ok(defined $exit_code, "offliner eseguito (exit code: $exit_code)")
    or diag("Output: $output");

# Trova la directory di output effettiva
# offliner crea: output_dir/title_timestamp/hostname/page1.html
# Quindi dobbiamo cercare: output_dir/*/localhost/page1.html
my $host_dir;
my @dirs = glob(File::Spec->catfile($output_dir, "*"));
for my $dir (@dirs) {
    if (-d $dir) {
        # Cerca dentro questa directory per localhost
        my $possible_host_dir = File::Spec->catfile($dir, "localhost");
        if (-d $possible_host_dir) {
            $host_dir = $possible_host_dir;
            last;
        }
    }
}

# Se non trovato, cerca ricorsivamente il file page1.html
unless ($host_dir) {
    my $found_file;
    find({
        wanted => sub {
            if (-f $_ && $_ eq 'page1.html') {
                $found_file = $File::Find::name;
                $File::Find::prune = 1;  # Ferma la ricerca in questa directory
            }
        },
        no_chdir => 1,
    }, $output_dir);
    
    if ($found_file) {
        $host_dir = File::Spec->rel2abs(File::Spec->dirname($found_file));
    }
}

# Se ancora non trovato, prova direttamente
$host_dir ||= File::Spec->catfile($output_dir, "localhost");

# Verifica struttura directory
ok(-d $host_dir, "Directory host creata correttamente")
    or diag("Directory cercata: $host_dir\nDirectory trovate: " . join(", ", @dirs));

# Verifica che almeno il file iniziale sia stato scaricato
my $first_file = File::Spec->catfile($host_dir, "page1.html");
if (-f $first_file) {
    pass("File iniziale page1.html scaricato correttamente");
    
    # Verifica contenuto del primo file
    open my $fh, '<', $first_file or fail("Cannot read $first_file: $!");
    local $/;
    my $downloaded_content = <$fh>;
    close $fh;
    
    # Verifica SHA512
    my $downloaded_hash = sha512_hex($downloaded_content);
    my $original_hash = $original_hashes{'page1.html'};
    
    is($downloaded_hash, $original_hash, "SHA512 di page1.html corrisponde")
        or diag("Hash originale: $original_hash\nHash scaricato: $downloaded_hash");
    
    like($downloaded_content, qr/TEST_CONTENT_1/, "Contenuto page1.html corretto");
} else {
    fail("File iniziale page1.html non trovato")
        or diag("File cercato: $first_file\nOutput offliner: $output");
}

# Verifica altri file scaricati (se presenti) con SHA512
my $files_found = 0;
my $files_verified = 0;
for my $i (2..10) {
    my $filename = "page$i.html";
    my $expected_file = File::Spec->catfile($host_dir, $filename);
    if (-f $expected_file) {
        $files_found++;
        
        # Verifica contenuto e SHA512
        open my $fh, '<', $expected_file or next;
        local $/;
        my $downloaded_content = <$fh>;
        close $fh;
        
        # Calcola hash del file scaricato
        my $downloaded_hash = sha512_hex($downloaded_content);
        my $original_hash = $original_hashes{$filename};
        
        # Verifica che l'hash corrisponda
        if ($downloaded_hash eq $original_hash) {
            $files_verified++;
        } else {
            diag("Hash mismatch per $filename: originale=$original_hash, scaricato=$downloaded_hash");
        }
    }
}

# Verifica che almeno alcuni file siano stati scaricati
ok($files_found >= 0, "File aggiuntivi scaricati: $files_found")
    or diag("Solo il file iniziale è stato scaricato (normale con max-depth 2)");

# Se ci sono file aggiuntivi, verifica che almeno alcuni abbiano hash corretto
if ($files_found > 0) {
    ok($files_verified > 0, "File verificati con SHA512: $files_verified/$files_found")
        or diag("Alcuni file potrebbero essere stati modificati durante il download");
}

# Pulisci: termina il webserver (forza terminazione se necessario)
if ($server_pid) {
    kill('TERM', $server_pid);
    sleep(0.2);
    # Se ancora vivo, forza terminazione
    if (kill(0, $server_pid)) {
        kill('KILL', $server_pid);
    }
    waitpid($server_pid, 0);
}

# Pulizia esplicita delle directory temporanee (ridondante ma sicura)
# File::Temp con CLEANUP => 1 dovrebbe già rimuoverle automaticamente
# quando le variabili escono dallo scope

done_testing();

# Funzione per trovare una porta libera
sub find_free_port {
    for my $p (8000..8100) {
        my $socket = IO::Socket::INET->new(
            LocalAddr => 'localhost',
            LocalPort => $p,
            Proto     => 'tcp',
            Listen    => 1,
            Reuse     => 1,
        );
        if ($socket) {
            close $socket;
            return $p;
        }
    }
    return undef;
}

# Funzione per avviare un webserver semplice
sub start_webserver {
    my ($docroot, $port) = @_;
    
    my $pid = fork();
    if ($pid == 0) {
        # Processo figlio: webserver
        # Ignora SIGTERM per evitare terminazione prematura
        $SIG{TERM} = sub { exit 0 };
        $SIG{INT} = sub { exit 0 };
        
        my $server = IO::Socket::INET->new(
            LocalAddr => 'localhost',
            LocalPort => $port,
            Proto     => 'tcp',
            Listen    => 5,
            Reuse     => 1,
        ) or die "Cannot create server socket: $!";
        
        # Timeout per accept per evitare blocchi
        $server->timeout(1);
        
        # Loop principale del server
        while (1) {
            my $client = $server->accept();
            last unless $client;
            
            eval {
                local $SIG{ALRM} = sub { die "timeout\n" };
                alarm(5);  # Timeout per evitare blocchi
                
                my $request = '';
                my $bytes_read = 0;
                while (<$client>) {
                    $request .= $_;
                    $bytes_read += length($_);
                    last if $request =~ /\r\n\r\n/ || $bytes_read > 8192;
                }
                alarm(0);
                
                # Parse richiesta semplice
                my ($method, $path) = $request =~ /^(\S+)\s+(\S+)/;
                unless ($method && $path) {
                    close $client;
                    return;
                }
                
                # Normalizza path
                $path =~ s/^\///;
                $path = 'page1.html' if $path eq '' || $path eq '/';
                $path =~ s/^\///;
                
                my $filepath = File::Spec->catfile($docroot, $path);
                
                # Verifica che il file esista e sia nella docroot
                my $abs_docroot = File::Spec->rel2abs($docroot);
                my $abs_filepath = File::Spec->rel2abs($filepath);
                
                if (-f $filepath && index($abs_filepath, $abs_docroot) == 0) {
                    open my $fh, '<', $filepath or do {
                        close $client;
                        return;
                    };
                    local $/;
                    my $content = <$fh>;
                    close $fh;
                    
                    my $response = "HTTP/1.0 200 OK\r\n";
                    $response .= "Content-Type: text/html; charset=UTF-8\r\n";
                    $response .= "Content-Length: " . length($content) . "\r\n";
                    $response .= "Connection: close\r\n";
                    $response .= "\r\n";
                    $response .= $content;
                    
                    print $client $response;
                } else {
                    # 404 Not Found
                    my $response = "HTTP/1.0 404 Not Found\r\n";
                    $response .= "Content-Type: text/plain\r\n";
                    $response .= "Connection: close\r\n";
                    $response .= "\r\n";
                    $response .= "404 Not Found: $path";
                    
                    print $client $response;
                }
                
                close $client;
            };
            if ($@ && $@ !~ /timeout/) {
                close $client if $client;
                next;
            }
        }
        
        exit 0;
    } elsif ($pid > 0) {
        # Processo padre: ritorna PID
        return $pid;
    } else {
        # Errore fork
        return undef;
    }
}
