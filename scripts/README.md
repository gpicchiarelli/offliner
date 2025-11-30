# Scripts di Build e Validazione

Questa directory contiene script per la gestione della distribuzione CPAN.

## Script Disponibili

### build_cpan_dist.pl

Crea una distribuzione CPAN completa e pronta per la pubblicazione.

**Uso:**
```bash
perl scripts/build_cpan_dist.pl [--test] [--skip-tests]
```

**Opzioni:**
- `--test`: Esegue solo i test senza creare la distribuzione
- `--skip-tests`: Salta i test durante la build

**Cosa fa:**
1. Verifica prerequisiti
2. Pulisce build precedenti
3. Genera Makefile
4. Verifica sintassi
5. Esegue test (opzionale)
6. Aggiorna MANIFEST
7. Crea directory di distribuzione
8. Crea tarball `.tar.gz`

**Output:**
- `OffLiner-VERSION.tar.gz` - Distribuzione CPAN pronta

### validate_cpan.pl

Valida che tutti i file necessari per CPAN siano presenti e corretti.

**Uso:**
```bash
perl scripts/validate_cpan.pl
```

**Cosa verifica:**
- File essenziali (Makefile.PL, META.json, MANIFEST, etc.)
- Validità META.json
- Correttezza MANIFEST
- Presenza test files
- Sintassi Perl

**Exit code:**
- `0`: Validazione passata
- `1`: Errori trovati

## Esempi

### Build completa con test
```bash
perl scripts/build_cpan_dist.pl
```

### Build senza test (più veloce)
```bash
perl scripts/build_cpan_dist.pl --skip-tests
```

### Solo validazione
```bash
perl scripts/validate_cpan.pl
```

### Workflow completo
```bash
# 1. Valida
perl scripts/validate_cpan.pl

# 2. Build
perl scripts/build_cpan_dist.pl

# 3. Upload (se hai cpan-upload installato)
cpan-upload OffLiner-*.tar.gz
```

## Requisiti

- Perl 5.14+
- `ExtUtils::MakeMaker`
- `JSON::PP` (per validate_cpan.pl)
- `make` (sistema Unix)

## Note

Questi script sono utilizzati anche dai workflow GitHub Actions per la pubblicazione automatica su CPAN.

