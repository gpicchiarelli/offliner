# OffLiner - Scaricatore di siti web offline

![Perl Version](https://img.shields.io/badge/Perl-5.10%2B-blue) 
![License](https://img.shields.io/badge/license-BSD-green) 
![Version](https://img.shields.io/github/release/gpicchiarelli/offliner.svg)
![Downloads](https://img.shields.io/github/downloads/gpicchiarelli/offliner/total)
![Language](https://img.shields.io/github/languages/top/gpicchiarelli/offliner)
![Commit Activity](https://img.shields.io/github/commit-activity/m/gpicchiarelli/offliner)

## Descrizione
OffLiner e' un'utility in Perl per scaricare siti web e navigarli offline, mantenendo la struttura e i link.

### Caratteristiche principali:
- Scaricamento di interi siti web per la consultazione offline
- Supporto per HTTPS e connessioni SSL
- Download parallelo con multi-threading
- Salvataggio e sanificazione automatica dei nomi di file e directory
- Tentativi multipli in caso di errore di connessione
- Log degli errori per diagnosi e debugging

## Requisiti
- Perl 5.10 o superiore
- Connessione Internet per il download e l'installazione automatica dei moduli mancanti

## Moduli richiesti
I seguenti moduli Perl sono necessari per eseguire OffLiner:
- HTTP::Tiny
- HTML::LinkExtor
- URI
- File::Path
- File::Basename
- Getopt::Long
- LWP::UserAgent
- IO::Socket::SSL
- Mozilla::CA

OffLiner installerà automaticamente i moduli mancanti durante l'esecuzione.

## Installazione
Per avviare l'installazione automatica, eseguire il seguente comando:

```bash
perl offliner.pl --url https://example.com
```

I moduli richiesti verranno installati automaticamente tramite CPAN se non già presenti.

## Utilizzo
Esempio di utilizzo per scaricare un sito web con una profondità massima di 10 e 5 thread:

```bash
perl offliner.pl --url https://example.com --max-depth 10 --max-threads 5
```

### Opzioni disponibili:
- `--url` (Obbligatorio): URL del sito da scaricare.
- `--user-agent`: Specifica un User-Agent personalizzato. Default: 'Mozilla/5.0 (compatible; OffLinerBot/1.0)'.
- `--max-depth`: Profondità massima dei link da seguire. Default: 50.
- `--max-threads`: Numero massimo di thread per il download parallelo. Default: 10.

## Documentazione
Puoi consultare la documentazione completa eseguendo:

```bash
perldoc offliner.pl
```

## Log e Debugging
Tutti gli errori verranno registrati in un file di log `download_log.txt` nella directory di esecuzione.

## Licenza
OffLiner è distribuito sotto licenza BSD. Consulta il file [LICENSE](./LICENSE) per maggiori dettagli.

## Autori
OffLiner Team
