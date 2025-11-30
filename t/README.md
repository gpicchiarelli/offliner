# Test Suite per OffLiner

Questa directory contiene la suite completa di test per OffLiner.

## Struttura dei Test

- `00_basic.t` - Test base: verifica esistenza e permessi dello script
- `01_syntax.t` - Test sintassi: verifica che lo script abbia sintassi Perl valida
- `02_help.t` - Test help: verifica che l'opzione --help funzioni
- `03_options.t` - Test opzioni: verifica validazione delle opzioni da riga di comando
- `04_modules.t` - Test moduli: verifica che tutti i moduli richiesti siano disponibili
- `05_integration.t` - Test integrazione: placeholder per test di integrazione completi
- `06_cleanup.t` - Test cleanup: verifica che non vengano lasciati file temporanei
- `07_functional.t` - Test funzionale: test completo con server HTTP mock (richiede HTTP::Server::Simple)
- `08_utils.t` - Test utility: test delle funzioni utility
- `09_error_handling.t` - Test gestione errori: verifica gestione corretta degli errori
- `10_cleanup_complete.t` - Test cleanup completo: verifica cleanup completo in vari scenari
- `test_helper.pl` - Helper per i test: funzioni comuni e cleanup automatico

## Eseguire i Test

### Tutti i test

```bash
perl Makefile.PL
make test
```

### Singolo test

```bash
prove t/00_basic.t
# oppure
perl -I. t/00_basic.t
```

### Con verbose

```bash
prove -v t/
```

## Cleanup Automatico

Tutti i test utilizzano `File::Temp` con `CLEANUP => 1` per garantire che:
- Le directory temporanee vengano rimosse automaticamente
- I file temporanei non vengano lasciati nel filesystem
- Non ci sia "sporcizia" dopo l'esecuzione dei test

Il file `test_helper.pl` fornisce funzioni aggiuntive per il cleanup automatico.

## Dipendenze di Test

I test richiedono:
- `Test::More` (standard)
- `File::Temp` (standard)
- `File::Spec` (standard)
- `FindBin` (standard)
- `Cwd` (standard)
- `File::Find` (standard)
- `Time::HiRes` (standard)
- `IO::Socket::INET` (standard)

Per i test funzionali completi (07_functional.t):
- `HTTP::Server::Simple` (opzionale, il test viene saltato se non disponibile)

## Note

- I test che richiedono connessione internet o server mock possono essere saltati se le dipendenze non sono disponibili
- I test utilizzano timeout per evitare che si blocchino indefinitamente
- Tutti i file temporanei vengono rimossi automaticamente, anche in caso di errore

