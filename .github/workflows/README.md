# GitHub Actions Workflows

Questo repository include i seguenti workflow GitHub Actions:

## Workflow Essenziali

### 1. `test.yml` - Test Automatici
**Quando si attiva**: Push e Pull Request su main/master

**Cosa fa**:
- Esegue test su multiple versioni di Perl (5.14, 5.18, 5.24, 5.30, 5.36)
- Verifica supporto threads prima di eseguire i test
- Testa su Ubuntu e macOS
- Cache delle dipendenze CPAN per velocità

**Status**: ✅ Essenziale

### 2. `cpan-release.yml` - Pubblicazione CPAN
**Quando si attiva**: GitHub Release pubblicata

**Cosa fa**:
- Valida la distribuzione CPAN
- Build della distribuzione
- Esegue test
- Upload automatico su CPAN (se secrets configurati)

**Status**: ✅ Essenziale per pubblicazione CPAN

### 3. `cpan-test.yml` - Test Distribuzione CPAN
**Quando si attiva**: Push, Pull Request, settimanale

**Cosa fa**:
- Testa l'installazione da tarball CPAN
- Verifica che la distribuzione sia installabile
- Testa su multiple versioni Perl

**Status**: ✅ Utile per validare distribuzione

### 4. `perlcritic.yml` - Analisi Qualità Codice
**Quando si attiva**: Push e Pull Request

**Cosa fa**:
- Esegue Perl::Critic sul codice
- Verifica best practices Perl
- Non blocca il workflow (solo warning)

**Status**: ⚠️ Opzionale ma utile

## Workflow Rimossi

- `codeql.yml` - Rimosso (CodeQL non supporta Perl)
- `test-legacy.yml` - Rimosso (non necessario)
- `manual-cpan-build.yml` - Rimosso (ridondante con cpan-release.yml)

## Note

Tutti i workflow verificano il supporto threads prima di eseguire test, poiché OffLiner richiede Perl compilato con supporto threads.

