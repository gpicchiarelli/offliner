# OffLiner - Scaricatore di siti web offline

OffLiner è un'utility Perl progettata per scaricare siti web e navigarli offline, mantenendo la struttura e i link. È particolarmente utile per creare copie locali di siti per una consultazione offline, preservando la navigabilità del sito scaricato.

## Funzionalità

- **Scaricamento parallelo di pagine web** utilizzando thread per velocizzare il processo.
- **Gestione automatica dei moduli Perl mancanti**: l'utility verifica e installa automaticamente i moduli necessari.
- **Salvataggio del contenuto delle pagine** in una struttura di directory locale, riproducendo l'architettura originale del sito.
- **Registrazione degli errori** in un file di log per monitorare eventuali problemi durante il download.
- **Personalizzazione dell'User-Agent** e della profondità di scaricamento, per configurare il comportamento del programma in base alle necessità.
- **Profondità illimitata** di scaricamento, configurabile tramite un parametro per limitare il numero di livelli di navigazione.

## Installazione

Assicurati di avere Perl installato sul tuo sistema. Puoi installare i moduli Perl necessari usando `cpan`:

```sh
cpan HTTP::Tiny HTML::LinkExtor URI File::Path File::Basename Getopt::Long LWP::UserAgent threads Thread::Queue
Requisiti
Perl 5.x o superiore
Moduli Perl:
HTTP::Tiny: per effettuare le richieste HTTP
HTML::LinkExtor: per analizzare i link nelle pagine HTML
URI: per gestire i link relativi e assoluti
File::Path: per creare le cartelle di destinazione
File::Basename: per estrarre i nomi dei file dalle URL
Getopt::Long: per il parsing dei parametri della linea di comando
LWP::UserAgent: per gestire le richieste HTTP avanzate
threads e Thread::Queue: per scaricare le pagine in parallelo
Utilizzo

Dopo aver installato i moduli, puoi eseguire l'utility dalla linea di comando:

perl offliner.pl <URL del sito da scaricare> [opzioni]
Esempio di esecuzione
Per scaricare un sito con profondità illimitata e salvare il tutto nella cartella offline_copy:

perl offliner.pl http://esempio.com
Per specificare una profondità di 3 livelli:

perl offliner.pl http://esempio.com 3
Opzioni
--depth <n>: imposta la profondità di scaricamento. Se non specificato, la profondità è illimitata.
--output-dir <dir>: specifica la directory di destinazione per il sito scaricato (predefinito: offline_copy).
--user-agent <user-agent>: personalizza l'User-Agent per simulare diverse richieste.
--log <file>: specifica il file di log dove registrare eventuali errori.
Compilazione in Eseguibile

Per rendere OffLiner un'applicazione eseguibile su diverse piattaforme, puoi utilizzare PAR::Packer o pp:

Compilare per Windows:
pp -o offliner.exe offliner.pl
Compilare per macOS e Linux:
pp -o offliner-mac offliner.pl
pp -o offliner-linux offliner.pl
Compilare per BSD:
pp -o offliner-bsd offliner.pl
Licenza

OffLiner è distribuito con licenza BSD. Consulta il file LICENSE per maggiori dettagli.
