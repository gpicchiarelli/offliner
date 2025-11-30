# OffLiner

<div align="center">

![Perl Version](https://img.shields.io/badge/Perl-5.14%2B-blue.svg)
![License](https://img.shields.io/badge/license-BSD--3--Clause-green.svg)
![Version](https://img.shields.io/github/v/release/gpicchiarelli/offliner?include_prereleases)
![Tests](https://github.com/gpicchiarelli/offliner/workflows/Tests/badge.svg)
![Language](https://img.shields.io/github/languages/top/gpicchiarelli/offliner)
![CPAN](https://img.shields.io/cpan/v/OffLiner.svg)

**Un'utility Perl professionale per scaricare siti web e navigarli offline**

[Caratteristiche](#-caratteristiche) • [Installazione](#-installazione) • [Utilizzo](#-utilizzo) • [Documentazione](#-documentazione) • [Contribuire](#-contribuire)

</div>

---

## 📖 Descrizione

**OffLiner** è un tool da riga di comando scritto in Perl per scaricare interi siti web e navigarli offline. Mantiene la struttura originale del sito, gestisce i link interni, scarica risorse (CSS, JavaScript, immagini) e supporta download parallelo multi-thread per massime performance.

Ideale per:
- 📚 Archiviare documentazione e tutorial
- 🔍 Creare backup di siti web
- 📱 Navigare contenuti offline
- 🎓 Studiare siti web localmente
- 📦 Preparare contenuti per distribuzione offline

## ✨ Caratteristiche

### 🚀 Performance e Concorrenza
- **Download parallelo multi-thread** - Scarica più pagine contemporaneamente (configurabile)
- **Thread-safe** - Sincronizzazione sicura con semafori e strutture dati condivise
- **Ottimizzazioni avanzate** - Riutilizzo LWP::UserAgent, cache directory, monitoraggio efficiente thread
- **Gestione intelligente della coda** - Uso di `dequeue_timed()` per ridurre CPU idle

### 🔒 Affidabilità e Sicurezza
- **Retry automatico** - Gestione intelligente degli errori con tentativi multipli configurabili
- **Supporto HTTPS/SSL** - Download sicuri con verifica certificati (Mozilla::CA)
- **Validazione URL** - Controllo precoce degli input per fail-fast
- **Terminazione pulita** - Gestione corretta di SIGINT/SIGTERM con cleanup dei thread

### 📝 Gestione Contenuti
- **Rilevamento codifica automatico** - Gestione corretta di charset e encoding (UTF-8, ISO-8859-1, ecc.)
- **Struttura directory intelligente** - Mantiene la struttura originale del sito
- **Sanificazione nomi file** - Rimuove caratteri problematici automaticamente per compatibilità cross-platform
- **Supporto file binari** - Rileva e scarica correttamente immagini, CSS, JS, PDF, ecc.
- **Seguire solo link dello stesso dominio** - Evita download infiniti e mantiene il focus sul sito target

### 📊 Monitoraggio e Debugging
- **Statistiche in tempo reale** - Conta pagine scaricate e fallite
- **Log dettagliati** - Registra tutti gli errori con timestamp in `download_log.txt`
- **Output verboso** - Modalità `--verbose` per debugging dettagliato
- **Notifiche macOS** - Notifiche automatiche al completamento (solo macOS)

### 🍎 Integrazione macOS
- **Installazione automatica** - Script di setup completo
- **Completamento automatico** - Supporto zsh completion
- **Quick Action Finder** - Download diretto da Finder
- **Alias rapidi** - Comandi `off` e `offline` per accesso veloce

## 📋 Requisiti

- **Perl 5.14 o superiore** (richiesto per `threads` e altre funzionalità moderne)
- **Moduli Perl** (vedi sezione [Installazione](#-installazione))

### Moduli Richiesti

- `LWP::UserAgent` (≥ 6.00)
- `URI` (≥ 1.60)
- `File::Path` (≥ 2.00)
- `Getopt::Long` (≥ 2.30)
- `Time::Piece` (≥ 1.20)
- `threads` (≥ 1.83)
- `Thread::Queue` (≥ 3.00)
- `threads::shared` (≥ 1.40)
- `Thread::Semaphore` (≥ 2.10)
- `Encode` (≥ 2.00)
- `HTML::LinkExtor` (≥ 1.00)
- `HTML::HeadParser` (≥ 3.60)
- `IO::Socket::SSL` (≥ 2.000)
- `Mozilla::CA` (≥ 20160104)

## 🚀 Installazione

### 🍎 macOS (Consigliata)

Per un'installazione completa con tutte le integrazioni macOS:

```bash
git clone https://github.com/gpicchiarelli/offliner.git
cd offliner
chmod +x macos/install.sh
./macos/install.sh
```

Questo installer automatico:
- ✅ Installa tutte le dipendenze Perl
- ✅ Configura il comando `offliner` nel PATH
- ✅ Aggiunge completamento automatico per zsh
- ✅ Installa Quick Action per Finder
- ✅ Configura notifiche macOS
- ✅ Crea alias utili (`off` e `offline`)

**Disinstallazione:**
```bash
./macos/uninstall.sh
```

### Installazione Rapida (Tutti i Sistemi)

#### Con cpanminus (consigliato)

```bash
git clone https://github.com/gpicchiarelli/offliner.git
cd offliner
cpanm --installdeps .
```

#### Con cpan

```bash
git clone https://github.com/gpicchiarelli/offliner.git
cd offliner
cpan --installdeps .
```

### Installazione come Modulo Perl

```bash
perl Makefile.PL
make
make test
sudo make install  # Richiede permessi root
```

### Installazione da CPAN

```bash
# Con cpanminus (consigliato)
cpanm OffLiner

# Oppure con cpan
cpan OffLiner
```

Dopo l'installazione da CPAN, il comando `offliner` sarà disponibile globalmente.

## 💻 Utilizzo

### Esempio Base

```bash
# Dopo installazione macOS
offliner --url https://example.com

# Oppure con alias (macOS)
offline --url https://example.com

# Installazione manuale
perl offliner.pl --url https://example.com
```

### Esempi Avanzati

#### Download con opzioni personalizzate

```bash
offliner \
  --url https://example.com \
  --output-dir ~/Downloads/OffLiner \
  --max-depth 10 \
  --max-threads 5 \
  --verbose
```

#### Download con User-Agent personalizzato

```bash
offliner \
  --url https://example.com \
  --user-agent "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
```

#### Download con retry aumentati

```bash
offliner \
  --url https://example.com \
  --max-retries 5 \
  --max-threads 8
```

### Opzioni Disponibili

| Opzione | Descrizione | Default | Esempio |
|---------|-------------|---------|---------|
| `--url URL` | URL del sito da scaricare (obbligatorio) | - | `--url https://example.com` |
| `--output-dir DIR` | Directory di output | Directory corrente | `--output-dir ~/Downloads` |
| `--user-agent STRING` | User-Agent personalizzato | `Mozilla/5.0 (compatible; OffLinerBot/1.0)` | `--user-agent "MyBot/1.0"` |
| `--max-depth N` | Profondità massima dei link | `50` | `--max-depth 10` |
| `--max-threads N` | Numero massimo di thread | `10` | `--max-threads 5` |
| `--max-retries N` | Numero massimo di tentativi per URL | `3` | `--max-retries 5` |
| `--verbose, -v` | Output verboso con informazioni di debug | Disabilitato | `--verbose` |
| `--help, -h` | Mostra messaggio di aiuto | - | `--help` |

### 🍎 Funzionalità macOS

Dopo l'installazione su macOS, OffLiner include:

- **🔔 Notifiche automatiche**: Ricevi una notifica quando il download è completato
- **⌨️ Completamento automatico**: Premi TAB per completare comandi e opzioni in zsh
- **🔧 Quick Action Finder**: Clic destro su un URL → "Download with OffLiner"
- **📂 Apertura automatica**: Finder si apre automaticamente nella directory di output
- **⚡ Alias rapidi**: Usa `off` o `offline` invece di `offliner`

## 📚 Documentazione

### Documentazione POD

Documentazione completa disponibile tramite POD:

```bash
perldoc offliner.pl
```

Oppure consulta la documentazione online nel codice sorgente.

### Documentazione Aggiuntiva

- **[CHANGELOG.md](./CHANGELOG.md)** - Storico completo delle modifiche
- **[PERFORMANCE.md](./PERFORMANCE.md)** - Ottimizzazioni e best practices per le performance
- **[RELEASE.md](./RELEASE.md)** - Guida al processo di release

## 🧪 Testing

Esegui la suite di test completa:

```bash
perl Makefile.PL
make test
```

Oppure esegui i test direttamente:

```bash
prove -l t/
```

### Test Disponibili

- `00_basic.t` - Test base di funzionalità
- `01_syntax.t` - Verifica sintassi
- `02_help.t` - Test messaggio di aiuto
- `03_options.t` - Test opzioni da riga di comando
- `04_modules.t` - Verifica moduli richiesti
- `05_integration.t` - Test di integrazione
- `06_cleanup.t` - Test cleanup e terminazione
- `07_functional.t` - Test funzionali
- `08_utils.t` - Test utility functions
- `09_error_handling.t` - Test gestione errori
- `10_cleanup_complete.t` - Test cleanup completo

## 📝 Log e Debugging

### File di Log

Tutti gli errori vengono registrati in `download_log.txt` nella directory di output con formato:

```
[YYYY-MM-DD HH:MM:SS] Messaggio di errore
```

### Modalità Verbosa

Usa `--verbose` per output dettagliato durante l'esecuzione:

```bash
offliner --url https://example.com --verbose
```

Questo mostra:
- URL in fase di download
- Errori in tempo reale
- Informazioni di debug
- Statistiche parziali

### Statistiche Finali

Al termine del download, OffLiner mostra:
- ✅ Numero di pagine scaricate con successo
- ❌ Numero di pagine fallite
- 📁 Percorso della directory di output
- 📋 Percorso del file di log

## ⚙️ Configurazione e Best Practices

### Configurazione Consigliata

Per massime performance:

- **`--max-threads`**: 5-10 (dipende dalla CPU e dalla banda)
  - CPU con 4 core: 5-8 thread
  - CPU con 8+ core: 8-15 thread
- **`--max-depth`**: Limita in base alle tue esigenze (default 50 è generoso)
- **`--max-retries`**: 3 (default, aumentare solo se necessario)

### Limitazioni e Comportamento

- ⚠️ **Solo stesso dominio**: OffLiner segue solo link dello stesso dominio per evitare download infiniti
- 📁 **Struttura preservata**: I file vengono salvati mantenendo la struttura originale del sito
- 🔤 **Nomi sanificati**: I nomi di file vengono sanificati automaticamente per compatibilità cross-platform
- 🛑 **Terminazione pulita**: La terminazione con Ctrl+C viene gestita correttamente, permettendo ai thread di completare

### Esempi di Uso Comune

#### Archiviare documentazione

```bash
offliner --url https://docs.example.com --output-dir ~/Documents/Archives
```

#### Backup rapido di un sito

```bash
offliner --url https://example.com --max-depth 5 --max-threads 8
```

#### Download con logging dettagliato

```bash
offliner --url https://example.com --verbose > download.log 2>&1
```

## 🤝 Contribuire

Contributi sono benvenuti! OffLiner è un progetto open source e ogni contributo è apprezzato.

### Come Contribuire

1. **Fork** del repository
2. **Crea un branch** per la tua feature (`git checkout -b feature/AmazingFeature`)
3. **Commit** delle modifiche (`git commit -m 'Aggiunge AmazingFeature'`)
4. **Push** al branch (`git push origin feature/AmazingFeature`)
5. **Apri una Pull Request**

### Linee Guida

- Segui lo stile di codice esistente
- Aggiungi test per nuove funzionalità
- Aggiorna la documentazione se necessario
- Assicurati che tutti i test passino (`make test`)
- Verifica la sintassi Perl (`perl -c offliner.pl`)

### Segnalazione Bug

Se trovi un bug, per favore apri una [issue](https://github.com/gpicchiarelli/offliner/issues) con:

- Descrizione dettagliata del problema
- Passi per riprodurre
- Output di errori (se presenti)
- Versione di Perl (`perl -v`)
- Sistema operativo
- Output di `--verbose` (se applicabile)

### Richiesta Funzionalità

Per richiedere nuove funzionalità, apri una [issue](https://github.com/gpicchiarelli/offliner/issues) con:

- Descrizione della funzionalità desiderata
- Caso d'uso e motivazione
- Esempi di utilizzo (se applicabile)

## 📊 Performance

OffLiner include diverse ottimizzazioni per massimizzare le performance:

- **Riutilizzo LWP::UserAgent**: Ogni thread crea un singolo UserAgent e lo riutilizza
- **Cache directory**: Evita chiamate filesystem ridondanti
- **Monitoraggio efficiente thread**: Uso di `dequeue_timed()` invece di polling continuo
- **Thread-safe ottimizzato**: Sincronizzazione minimale per ridurre lock contention

Per dettagli completi, consulta [PERFORMANCE.md](./PERFORMANCE.md).

### Metriche Tipiche

- **CPU idle**: ~1-2% durante attesa (vs ~15-20% prima delle ottimizzazioni)
- **Memoria per thread**: ~1.5-2MB
- **Throughput**: Dipende dalla banda e dal numero di thread

## 📄 Licenza

OffLiner è distribuito sotto licenza **BSD 3-Clause License**.

```
Copyright (c) 2024, Giacomo Picchiarelli

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.
```

Consulta il file [LICENSE](./LICENSE) per il testo completo.

## 👤 Autore

**Giacomo Picchiarelli**

- 🌐 GitHub: [@gpicchiarelli](https://github.com/gpicchiarelli)
- 📧 Repository: [offliner](https://github.com/gpicchiarelli/offliner)

## 🙏 Ringraziamenti

- Tutti i contributori che hanno aiutato a migliorare OffLiner
- La comunità Perl per gli ottimi moduli disponibili
- I maintainer dei moduli CPAN utilizzati

## 🔗 Link Utili

- 📦 [CPAN](https://metacpan.org/release/OffLiner) - Pagina CPAN del modulo
- 🐛 [Issues](https://github.com/gpicchiarelli/offliner/issues) - Segnala bug o richiedi funzionalità
- 💬 [Discussions](https://github.com/gpicchiarelli/offliner/discussions) - Discussioni e domande
- 📚 [Documentazione POD](https://metacpan.org/pod/OffLiner) - Documentazione completa

## 📜 Changelog

Vedi [CHANGELOG.md](./CHANGELOG.md) per la lista completa delle modifiche.

## ⭐ Stargazers

Se OffLiner ti è utile, considera di dare una ⭐ al repository!

---

<div align="center">

**Fatto con ❤️ in Perl**

[⬆ Torna all'inizio](#offliner)

</div>
