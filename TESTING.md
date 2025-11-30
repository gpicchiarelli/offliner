# Guida ai Test

Questa guida spiega come eseguire i test per OffLiner.

## Metodi per Eseguire i Test

### 1. Con `prove` (Raccomandato)

`prove` è il tool moderno e veloce per eseguire test Perl.

```bash
# Esegui tutti i test
prove -l t/

# Esegui un singolo test
prove -l t/12_stats.t

# Esegui test con output verboso
prove -l -v t/

# Esegui test con output colorato
prove -l --color t/

# Esegui solo test che falliscono
prove -l --state=save t/
prove -l --state=failed t/
```

**Installazione di prove:**
```bash
cpanm App::Prove
# oppure
cpan App::Prove
```

### 2. Con `make`

Se hai generato il Makefile:

```bash
# Genera il Makefile (se non presente)
perl Makefile.PL

# Esegui tutti i test
make test

# Esegui test con output verboso
make test TEST_VERBOSE=1
```

### 3. Direttamente con `perl`

```bash
# Singolo test
perl -Ilib t/12_stats.t

# Tutti i test (con Test::Harness)
perl -Ilib -MTest::Harness -e 'runtests(@ARGV)' t/*.t

# Con output verboso
perl -Ilib -MTest::Harness -e 'runtests(@ARGV)' t/*.t -v
```

### 4. Con `perl` e `Test::More` direttamente

```bash
# Singolo test
perl -Ilib t/12_stats.t

# Con output dettagliato
perl -Ilib -MTest::More t/12_stats.t
```

## Test Disponibili

Elenco dei file di test in `t/`:

- `00_basic.t` - Test base
- `01_syntax.t` - Verifica sintassi
- `02_help.t` - Test help
- `03_options.t` - Test opzioni
- `04_modules.t` - Verifica moduli
- `05_integration.t` - Test integrazione
- `06_cleanup.t` - Test cleanup
- `07_functional.t` - Test funzionali
- `08_utils.t` - Test utility
- `09_error_handling.t` - Test gestione errori
- `10_cleanup_complete.t` - Test cleanup completo
- `11_macos_integration.t` - Test integrazione macOS
- `12_stats.t` - Test statistiche base
- `13_stats_integration.t` - Test integrazione statistiche
- `14_stats_display.t` - Test display statistiche
- `15_network_speed.t` - Test velocità di rete
- `16_stats_formatting.t` - Test formattazione
- `17_stats_threads.t` - Test statistiche con thread
- `18_pod.t` - Test documentazione POD
- `19_perlcritic.t` - Test qualità codice
- `20_kwalitee.t` - Test qualità distribuzione

## Esempi Pratici

### Eseguire tutti i test
```bash
prove -l t/
```

### Eseguire solo test statistiche
```bash
prove -l t/12_stats.t t/13_stats_integration.t t/14_stats_display.t
```

### Eseguire test con output dettagliato
```bash
prove -l -v t/12_stats.t
```

### Eseguire test e salvare lo stato
```bash
prove -l --state=save t/
# Poi rieseguire solo quelli falliti
prove -l --state=failed t/
```

### Eseguire test in parallelo (più veloce)
```bash
prove -l -j4 t/  # 4 job in parallelo
```

### Eseguire test con timeout
```bash
prove -l --timer t/
```

## Troubleshooting

### Test falliscono con "Can't locate module"
Assicurati di essere nella directory root del progetto e di avere installato le dipendenze:
```bash
cpanm --installdeps .
```

### Test falliscono su macOS
Alcuni test (come `11_macos_integration.t`) sono specifici per macOS e verranno saltati su altri sistemi.

### Test POD falliscono
Installa i moduli opzionali:
```bash
cpanm Test::Pod Test::Pod::Coverage
```

### Test Perl::Critic fallisce
Installa Perl::Critic:
```bash
cpanm Perl::Critic
```

## Output dei Test

I test usano il formato TAP (Test Anything Protocol). Esempio:

```
t/12_stats.t .. ok
t/13_stats.t .. ok
All tests successful.
Files=2, Tests=25,  2 wallclock secs
Result: PASS
```

- `ok` = test passato
- `not ok` = test fallito
- `# skip` = test saltato
- `# TODO` = test in sviluppo

## Integrazione CI/CD

I test vengono eseguiti automaticamente nei workflow GitHub Actions:
- `.github/workflows/test.yml`
- `.github/workflows/comprehensive-tests.yml`
- `.github/workflows/stats-tests.yml`

