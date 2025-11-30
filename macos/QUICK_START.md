# 🚀 Quick Start - OffLiner per macOS

## Installazione in 3 Passi

```bash
# 1. Clona il repository
git clone https://github.com/gpicchiarelli/offliner.git
cd offliner

# 2. Rendi eseguibili gli script
chmod +x macos/*.sh

# 3. Esegui il setup automatico
./macos/setup_macos.sh
```

**Fatto!** 🎉 Ora puoi usare OffLiner immediatamente.

## Uso Immediato

### Dalla riga di comando

```bash
# Download base
offliner --url https://example.com

# Con alias (più veloce)
offline --url https://example.com

# Con opzioni personalizzate
offliner --url https://example.com --max-depth 5 --max-threads 8 --verbose
```

### Da Finder (Quick Action)

1. Seleziona un URL in qualsiasi app (Safari, Notes, TextEdit, ecc.)
2. Clic destro → **Servizi** → **Download with OffLiner**
3. Il download parte automaticamente!

**Nota**: Se non vedi la Quick Action, riavvia Finder:
```bash
killall Finder
```

## Funzionalità macOS

✅ **Notifiche automatiche** quando il download è completato  
✅ **Completamento automatico** comandi (premi TAB)  
✅ **Apertura automatica** Finder nella directory di output  
✅ **Quick Action** per download rapido da qualsiasi app  
✅ **Alias utili** (`off` e `offline`)

## Esempi Pratici

```bash
# Download di un sito completo
offline --url https://example.com

# Download con profondità limitata
offliner --url https://example.com --max-depth 3

# Download in directory specifica
offliner --url https://example.com --output-dir ~/Documents/MyDownloads

# Download con output verboso
offliner --url https://example.com --verbose
```

## Dove vengono salvati i file?

Per default: `~/Downloads/OffLiner/[sito]_[timestamp]/`

Puoi specificare una directory diversa con `--output-dir`.

## Aiuto

```bash
# Vedi tutte le opzioni
offliner --help

# Leggi la documentazione completa
perldoc offliner
```

## Problemi?

Vedi [macos/README.md](README.md) per la risoluzione dei problemi comuni.

