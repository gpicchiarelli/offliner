# Guida al Release

Questa guida spiega come rilasciare una nuova versione di OffLiner, sia su GitHub che su CPAN.

## Processo di Release

### 1. Preparazione

1. **Aggiorna la versione** in `offliner.pl`:
   ```perl
   our $VERSION = '1.0.1';  # Incrementa la versione
   ```

2. **Aggiorna CHANGELOG.md**:
   - Aggiungi una nuova sezione per la versione
   - Documenta tutte le modifiche

3. **Verifica localmente**:
   ```bash
   # Valida
   perl scripts/validate_cpan.pl
   
   # Build e test
   perl scripts/build_cpan_dist.pl
   ```

### 2. Commit e Tag

```bash
# Commit delle modifiche
git add .
git commit -m "Release v1.0.1"

# Crea tag
git tag -a v1.0.1 -m "Release version 1.0.1"

# Push
git push origin main
git push origin v1.0.1
```

### 3. GitHub Release

1. Vai su GitHub → Releases → "Draft a new release"
2. Seleziona il tag appena creato (es. `v1.0.1`)
3. Titolo: `Release v1.0.1`
4. Descrizione: Copia le note dal CHANGELOG.md
5. Pubblica la release

### 4. Pubblicazione Automatica su CPAN

Quando pubblichi la GitHub Release, il workflow `cpan-release.yml` viene attivato automaticamente e:

1. ✅ Valida la distribuzione
2. ✅ Esegue i test
3. ✅ Crea il tarball
4. ✅ Upload su CPAN (se i secrets sono configurati)

**Nota**: Assicurati di avere configurato i secrets `CPAN_USERNAME` e `CPAN_PASSWORD` in GitHub.

### 5. Verifica

Dopo qualche minuto, verifica che il modulo sia disponibile:

- [MetaCPAN](https://metacpan.org/release/OffLiner)
- [CPAN](https://search.cpan.org/dist/OffLiner/)

## Release Manuale (Alternativa)

Se preferisci pubblicare manualmente:

### Build Manuale

```bash
perl scripts/build_cpan_dist.pl
```

### Upload Manuale

```bash
cpan-upload OffLiner-*.tar.gz
```

Oppure usa il web interface su [pause.perl.org](https://pause.perl.org/)

## Versioning

Segui [Semantic Versioning](https://semver.org/):

- **MAJOR**: Cambiamenti incompatibili
- **MINOR**: Nuove funzionalità compatibili
- **PATCH**: Bug fix compatibili

Esempi:
- `1.0.0` → `1.0.1` (bug fix)
- `1.0.1` → `1.1.0` (nuova feature)
- `1.1.0` → `2.0.0` (breaking change)

## Checklist Pre-Release

- [ ] Versione aggiornata in `offliner.pl`
- [ ] CHANGELOG.md aggiornato
- [ ] Tutti i test passano
- [ ] Validazione CPAN passa
- [ ] Documentazione aggiornata
- [ ] Tag Git creato
- [ ] GitHub Release creata
- [ ] Secrets CPAN configurati (per upload automatico)

## Troubleshooting

### Workflow non si attiva

Verifica che:
- Il tag sia stato pushato
- La GitHub Release sia pubblicata (non draft)
- I workflow non siano disabilitati

### Upload CPAN fallisce

Verifica:
- Secrets GitHub configurati correttamente
- Credenziali PAUSE valide
- Permessi per pubblicare il modulo

### Test falliscono

Risolvi tutti i test falliti prima di rilasciare:
```bash
perl Makefile.PL
make test
```

## Risorse

- [CPAN.md](./CPAN.md) - Guida completa alla pubblicazione CPAN
- [CONTRIBUTING.md](./CONTRIBUTING.md) - Linee guida per contribuire
- [CHANGELOG.md](./CHANGELOG.md) - Storico delle modifiche

