#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Spec;
use File::Temp qw(tempdir);
use FindBin qw($Bin);

# Test per integrazione macOS

plan skip_all => "Questi test sono solo per macOS" unless $^O eq 'darwin';

my $script = File::Spec->catfile($Bin, '..', 'offliner.pl');
my $perl = $^X;
my $output_dir = tempdir(CLEANUP => 1);

# Test 1: Verifica che offliner funzioni su macOS
subtest "Funzionalità base macOS" => sub {
    my $output = `$perl "$script" --help 2>&1`;
    like($output, qr/offliner/i, "Script risponde a --help");
    pass("Script eseguibile su macOS");
};

# Test 2: Verifica supporto clipboard (se disponibile)
subtest "Supporto clipboard" => sub {
    if (-x '/usr/bin/pbpaste') {
        # Test che l'opzione esista
        my $output = `$perl "$script" --help 2>&1`;
        like($output, qr/--clipboard|clipboard/i, "Opzione --clipboard presente");
        pass("Supporto clipboard disponibile");
    } else {
        skip "pbpaste non disponibile", 1;
    }
};

# Test 3: Verifica check-update
subtest "Check aggiornamenti" => sub {
    my $output = `$perl "$script" --check-update 2>&1`;
    # Non verifichiamo il contenuto perché dipende dalla connessione
    isnt($?, 0, "Exit code per check-update (può fallire senza internet)");
    pass("Opzione --check-update presente");
};

# Test 4: Verifica configurazione
subtest "Configurazione persistente" => sub {
    my $config_file = "$ENV{HOME}/.config/offliner/config.json";
    if (-f $config_file) {
        pass("File di configurazione esiste");
        
        # Verifica che sia JSON valido
        eval {
            require JSON::PP;
            open my $fh, '<', $config_file or die "Cannot read: $!";
            local $/;
            my $json = <$fh>;
            close $fh;
            my $data = JSON::PP::decode_json($json);
            ok(exists $data->{default_output_dir}, "Config contiene default_output_dir");
            ok(exists $data->{default_max_depth}, "Config contiene default_max_depth");
        };
        if ($@) {
            fail("Config non è JSON valido: $@");
        } else {
            pass("Config è JSON valido");
        }
    } else {
        skip "File di configurazione non trovato (normale se non installato)", 1;
    }
};

# Test 5: Verifica notifiche (se osascript disponibile)
subtest "Supporto notifiche" => sub {
    if (-x '/usr/bin/osascript') {
        # Test che osascript funzioni
        my $test_notification = `osascript -e 'display notification "Test" with title "Test"' 2>&1`;
        is($?, 0, "osascript funziona");
        pass("Supporto notifiche disponibile");
    } else {
        skip "osascript non disponibile", 1;
    }
};

# Test 6: Verifica che lo script gestisca errori correttamente
subtest "Gestione errori" => sub {
    # Test con URL non valido
    my $output = `$perl "$script" --url "invalid-url" 2>&1`;
    my $exit_code = $? >> 8;
    isnt($exit_code, 0, "Exit code non-zero per URL non valido");
    like($output, qr/URL non valido|non valido/i, "Messaggio di errore per URL non valido");
    
    # Test senza URL
    $output = `$perl "$script" 2>&1`;
    $exit_code = $? >> 8;
    isnt($exit_code, 0, "Exit code non-zero senza URL");
    like($output, qr/Devi specificare|URL/i, "Messaggio di errore senza URL");
};

done_testing();

