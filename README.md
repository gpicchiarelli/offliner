# OffLiner - Scaricatore di siti web offline

![Perl Version](https://img.shields.io/badge/Perl-5.10%2B-blue) 
![License](https://img.shields.io/badge/license-BSD-green) 
![Version](https://img.shields.io/github/v/release/gpicchiarelli/offliner)
![Tests](https://github.com/gpicchiarelli/offliner/workflows/Tests/badge.svg)
![Language](https://img.shields.io/github/languages/top/gpicchiarelli/offliner)

OffLiner è un'utility Perl professionale per scaricare siti web e navigarli offline, mantenendo la struttura e i link. Supporta download parallelo multi-thread con sincronizzazione thread-safe, gestione errori avanzata e molto altro.

## ✨ Caratteristiche principali

- 🚀 **Download parallelo multi-thread** - Scarica più pagine contemporaneamente
- 🔒 **Thread-safe** - Sincronizzazione sicura con semafori
- 🔄 **Retry automatico** - Gestione intelligente degli errori con tentativi multipli
- 🔐 **Supporto HTTPS/SSL** - Download sicuri con verifica certificati
- 📝 **Rilevamento codifica automatico** - Gestione corretta di charset e encoding
- 📊 **Statistiche** - Conta pagine scaricate e fallite
- 🛑 **Terminazione pulita** - Gestione corretta di SIGINT/SIGTERM
- 📁 **Struttura directory intelligente** - Mantiene la struttura originale del sito
- 🧹 **Sanificazione nomi file** - Rimuove caratteri problematici automaticamente
- 📋 **Log dettagliati** - Registra tutti gli errori per debugging

## 📋 Requisiti

- Perl 5.10 o superiore
- Moduli Perl (vedi sezione Installazione)

## 🚀 Installazione

### Installazione rapida

```bash
git clone https://github.com/gpicchiarelli/offliner.git
cd offliner
cpanm --installdeps .
```

Oppure con cpan:

```bash
cpan --installdeps .
```

### Installazione come modulo Perl

```bash
perl Makefile.PL
make
make test
make install
```

### Installazione da CPAN

```bash
cpan OffLiner
# oppure
cpanm OffLiner
```

> **Nota**: Il modulo sarà disponibile su CPAN dopo la prima pubblicazione.

## 💻 Utilizzo

### Esempio base

```bash
perl offliner.pl --url https://example.com
```

### Esempio avanzato

```bash
perl offliner.pl \
  --url https://example.com \
  --output-dir /tmp/downloads \
  --max-depth 10 \
  --max-threads 5 \
  --verbose
```

### Opzioni disponibili

| Opzione | Descrizione | Default |
|---------|-------------|---------|
| `--url URL` | URL del sito da scaricare (obbligatorio) | - |
| `--output-dir DIR` | Directory di output | Directory corrente |
| `--user-agent STRING` | User-Agent personalizzato | Mozilla/5.0 (compatible; OffLinerBot/1.0) |
| `--max-depth N` | Profondità massima dei link | 50 |
| `--max-threads N` | Numero massimo di thread | 10 |
| `--verbose, -v` | Output verboso | Disabilitato |
| `--help, -h` | Mostra messaggio di aiuto | - |

## 📚 Documentazione

Documentazione completa disponibile tramite POD:

```bash
perldoc offliner.pl
```

Oppure consulta la documentazione online nel codice sorgente.

## 🧪 Testing

Esegui la suite di test:

```bash
perl Makefile.PL
make test
```

## 📝 Log e Debugging

Tutti gli errori vengono registrati in `download_log.txt` nella directory di output. Usa `--verbose` per output dettagliato durante l'esecuzione.

## 🤝 Contribuire

Contributi sono benvenuti! Leggi [CONTRIBUTING.md](./CONTRIBUTING.md) per le linee guida.

1. Fork del repository
2. Crea un branch per la tua feature (`git checkout -b feature/AmazingFeature`)
3. Commit delle modifiche (`git commit -m 'Aggiunge AmazingFeature'`)
4. Push al branch (`git push origin feature/AmazingFeature`)
5. Apri una Pull Request

## 📄 Licenza

OffLiner è distribuito sotto licenza BSD 3-Clause. Consulta il file [LICENSE](./LICENSE) per maggiori dettagli.

## 👤 Autore

**Giacomo Picchiarelli**

- GitHub: [@gpicchiarelli](https://github.com/gpicchiarelli)

## 🙏 Ringraziamenti

- Tutti i contributori che hanno aiutato a migliorare OffLiner
- La comunità Perl per gli ottimi moduli disponibili

## 📊 Statistiche

Al termine del download, OffLiner mostra:
- Numero di pagine scaricate con successo
- Numero di pagine fallite
- Percorso della directory di output
- Percorso del file di log

## ⚠️ Note importanti

- OffLiner segue solo link dello stesso dominio per evitare download infiniti
- I file vengono salvati mantenendo la struttura originale del sito
- I nomi di file vengono sanificati automaticamente per compatibilità cross-platform
- La terminazione con Ctrl+C viene gestita correttamente, permettendo ai thread di completare

## 🐛 Segnalazione Bug

Se trovi un bug, per favore apri una [issue](https://github.com/gpicchiarelli/offliner/issues) con:
- Descrizione del problema
- Passi per riprodurre
- Output di errori (se presenti)
- Versione di Perl e sistema operativo

## 📦 Pubblicazione CPAN

OffLiner è pubblicato su CPAN e può essere installato con:

```bash
cpan OffLiner
# oppure
cpanm OffLiner
```

Per informazioni sulla pubblicazione automatica, vedi [CPAN.md](./CPAN.md).

## 📜 Changelog

Vedi [CHANGELOG.md](./CHANGELOG.md) per la lista completa delle modifiche.
