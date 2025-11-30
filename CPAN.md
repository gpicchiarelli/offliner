# Pubblicazione su CPAN

Questa guida spiega come pubblicare OffLiner su CPAN in modo automatico.

## Prerequisiti

1. **Account PAUSE**: Registrati su [pause.perl.org](https://pause.perl.org/)
2. **Permessi modulo**: Assicurati di avere i permessi per pubblicare il modulo `OffLiner`

## Setup Automatico con GitHub Actions

### 1. Configurazione Secrets

Aggiungi i seguenti secrets nel repository GitHub:

- `CPAN_USERNAME`: Il tuo username PAUSE
- `CPAN_PASSWORD`: La tua password PAUSE (o token API se disponibile)

Per aggiungere secrets:
1. Vai su Settings → Secrets and variables → Actions
2. Clicca "New repository secret"
3. Aggiungi `CPAN_USERNAME` e `CPAN_PASSWORD`

### 2. Pubblicazione Automatica

La pubblicazione avviene automaticamente quando:

1. **Creazione di una Release**: Quando crei una nuova release su GitHub, il workflow `cpan-release.yml` viene attivato automaticamente
2. **Workflow Manuale**: Puoi attivare manualmente il workflow dalla sezione Actions

### 3. Processo di Pubblicazione

Il workflow esegue automaticamente:

1. ✅ Validazione della distribuzione
2. ✅ Build della distribuzione CPAN
3. ✅ Esecuzione dei test
4. ✅ Creazione del tarball
5. ✅ Upload su CPAN (se i secrets sono configurati)

## Pubblicazione Manuale

Se preferisci pubblicare manualmente:

### 1. Build della Distribuzione

```bash
perl scripts/build_cpan_dist.pl
```

Questo crea il file `OffLiner-VERSION.tar.gz`

### 2. Validazione

```bash
perl scripts/validate_cpan.pl
```

### 3. Upload su CPAN

```bash
cpan-upload OffLiner-VERSION.tar.gz
```

Oppure usa il web interface su [pause.perl.org](https://pause.perl.org/)

## Verifica Post-Pubblicazione

Dopo l'upload, verifica che il modulo sia disponibile:

1. **CPAN Search**: [search.cpan.org](https://search.cpan.org/)
2. **MetaCPAN**: [metacpan.org](https://metacpan.org/)

Il modulo dovrebbe essere disponibile entro pochi minuti dall'upload.

## Versioning

Il numero di versione viene letto automaticamente da `offliner.pl`:

```perl
our $VERSION = '1.0.0';
```

Per rilasciare una nuova versione:

1. Aggiorna `$VERSION` in `offliner.pl`
2. Aggiorna `CHANGELOG.md`
3. Crea un tag Git: `git tag -a v1.0.1 -m "Release 1.0.1"`
4. Push del tag: `git push origin v1.0.1`
5. Crea una GitHub Release con lo stesso tag

## Test Locale della Distribuzione

Prima di pubblicare, testa la distribuzione localmente:

```bash
# Build
perl scripts/build_cpan_dist.pl

# Estrai e testa
tar -xzf OffLiner-*.tar.gz
cd OffLiner-*
perl Makefile.PL
make
make test
make install DESTDIR=/tmp/test-install
```

## Troubleshooting

### Errore: "Module name already taken"

Il nome `OffLiner` potrebbe essere già preso. In questo caso:
- Contatta il maintainer del modulo esistente
- Oppure usa un nome alternativo (es. `App::OffLiner`)

### Errore: "Invalid PAUSE credentials"

Verifica che i secrets GitHub siano configurati correttamente e che le credenziali PAUSE siano valide.

### Errore: "Tests failed"

Assicurati che tutti i test passino localmente prima di pubblicare:

```bash
perl Makefile.PL
make test
```

## Best Practices

1. **Semantic Versioning**: Usa [Semantic Versioning](https://semver.org/) per i numeri di versione
2. **CHANGELOG**: Aggiorna sempre `CHANGELOG.md` prima di rilasciare
3. **Test**: Assicurati che tutti i test passino
4. **Documentazione**: Mantieni la documentazione aggiornata
5. **Backward Compatibility**: Cerca di mantenere la compatibilità con versioni precedenti

## Risorse

- [PAUSE](https://pause.perl.org/) - Perl Authors Upload Server
- [CPAN](https://www.cpan.org/) - Comprehensive Perl Archive Network
- [MetaCPAN](https://metacpan.org/) - Modern CPAN search
- [CPAN::Uploader](https://metacpan.org/pod/CPAN::Uploader) - Tool per upload

