# Changelog

Tutti i cambiamenti notevoli a questo progetto saranno documentati in questo file.

Il formato è basato su [Keep a Changelog](https://keepachangelog.com/it/1.0.0/),
e questo progetto aderisce a [Semantic Versioning](https://semver.org/lang/it/).

## [1.0.0] - 2024-12-XX

### Aggiunto
- Versione iniziale di OffLiner
- Download parallelo multi-thread con thread-safe synchronization
- Supporto HTTPS e SSL
- Rilevamento automatico della codifica
- Gestione errori con retry automatico
- Log degli errori
- Terminazione pulita con gestione segnali (SIGINT, SIGTERM)
- Statistiche di download (pagine scaricate/fallite)
- Supporto per file HTML e binari
- Sanificazione automatica dei nomi di file e directory
- Opzione --verbose per output dettagliato
- Opzione --output-dir per specificare la directory di output
- Validazione URL
- Seguire solo link dello stesso dominio (per evitare download infiniti)
- Documentazione POD completa
- Test suite base
- Makefile.PL per installazione CPAN
- META.json per metadati del progetto

### Corretto
- Thread safety: uso di threads::shared e Thread::Semaphore per proteggere l'hash %visited
- Terminazione corretta dei thread con sentinel values
- Rimozione di debug prints e codice commentato
- Fix variabile $content ridichiarata
- Migliorata gestione encoding
- Migliorata gestione errori

### Migliorato
- Installazione moduli: verifica presenza invece di installazione automatica
- Struttura del codice più pulita e professionale
- Documentazione migliorata
- Gestione file binari vs HTML
- Path generation più robusta


