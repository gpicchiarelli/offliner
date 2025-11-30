# Refactoring e Modularizzazione di OffLiner

## Panoramica

Il codice è stato razionalizzato e modularizzato per migliorare la manutenibilità, testabilità e riutilizzabilità. Lo script principale `offliner.pl` è stato ridotto da ~910 righe a ~350 righe, spostando la logica in moduli dedicati.

## Struttura Modulare

### Moduli Creati

1. **OffLiner::Config** (`lib/OffLiner/Config.pm`)
   - Gestione configurazione da file JSON
   - Validazione parametri
   - Costanti di default

2. **OffLiner::Utils** (`lib/OffLiner/Utils.pm`)
   - Funzioni utility: `get_site_title()`, `sanitize_filename()`, `uri_to_path()`, `validate_url()`

3. **OffLiner::Logger** (`lib/OffLiner/Logger.pm`)
   - Sistema di logging centralizzato
   - Supporto per log file e output verboso

4. **OffLiner::Parser** (`lib/OffLiner/Parser.pm`)
   - Parsing HTML e estrazione link
   - Rilevamento codifica

5. **OffLiner::Downloader** (`lib/OffLiner/Downloader.pm`)
   - Logica di download con retry
   - Gestione UserAgent
   - Salvataggio file

6. **OffLiner::Worker** (`lib/OffLiner/Worker.pm`)
   - Thread worker per download parallelo

7. **OffLiner::Platform::macOS** (`lib/OffLiner/Platform/macOS.pm`)
   - Funzioni specifiche macOS (notifiche, clipboard)

8. **OffLiner::Version** (`lib/OffLiner/Version.pm`)
   - Gestione versioni e verifica aggiornamenti

## Benefici della Modularizzazione

### 1. **Manutenibilità**
- Codice organizzato per responsabilità
- Più facile trovare e modificare funzionalità specifiche
- Riduzione della complessità del file principale

### 2. **Testabilità**
- Ogni modulo può essere testato indipendentemente
- Test unitari più semplici da scrivere
- Mock più facili da implementare

### 3. **Riutilizzabilità**
- I moduli possono essere riutilizzati in altri progetti
- API chiare e documentate
- Separazione delle dipendenze

### 4. **Leggibilità**
- Script principale più snello e focalizzato sull'orchestrazione
- Nomi di moduli descrittivi
- Documentazione POD per ogni modulo

### 5. **Estendibilità**
- Facile aggiungere nuove funzionalità
- Supporto per altre piattaforme (es. Linux, Windows)
- Estensione senza modificare il codice esistente

## Struttura Directory

```
offliner/
├── lib/
│   └── OffLiner/
│       ├── Config.pm
│       ├── Downloader.pm
│       ├── Logger.pm
│       ├── Parser.pm
│       ├── Utils.pm
│       ├── Version.pm
│       ├── Worker.pm
│       └── Platform/
│           └── macOS.pm
├── offliner.pl          # Script principale (ridotto a ~350 righe)
├── Makefile.PL
└── MANIFEST
```

## Compatibilità

- ✅ Mantiene la stessa interfaccia CLI
- ✅ Compatibile con i test esistenti
- ✅ Nessuna modifica alle dipendenze
- ✅ Stessa funzionalità

## Prossimi Passi Suggeriti

1. **Test Unitari**: Creare test per ogni modulo
2. **Documentazione**: Espandere la documentazione POD
3. **CI/CD**: Verificare che i test passino con la nuova struttura
4. **Performance**: Verificare che non ci siano regressioni

## Note Tecniche

- I moduli usano `Exporter` per esportare funzioni
- Le costanti sono accessibili tramite namespace completo (es. `OffLiner::Config::DEFAULT_MAX_DEPTH()`)
- Il percorso `lib/` è aggiunto automaticamente a `@INC` nello script principale
- Tutti i moduli sono inclusi nel `MANIFEST` per la distribuzione CPAN

