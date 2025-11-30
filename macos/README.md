# OffLiner - Integrazione macOS

Questa directory contiene tutti i file necessari per un'integrazione completa con macOS.

## 📋 Contenuti

- **install.sh** - Script di installazione completo per macOS
- **uninstall.sh** - Script di disinstallazione
- **setup_macos.sh** - Setup automatico completo (consigliato)
- **_offliner** - File di completamento automatico per zsh
- **Download with OffLiner.workflow** - Quick Action per Finder

## 🚀 Installazione Rapida

### Metodo 1: Setup Automatico (Consigliato)

```bash
cd offliner
chmod +x macos/*.sh
./macos/setup_macos.sh
```

Questo script:
1. Installa tutte le dipendenze
2. Configura il comando `offliner`
3. Aggiunge completamento automatico
4. Installa Quick Action Finder
5. Configura notifiche macOS
6. Crea alias utili

### Metodo 2: Installazione Manuale

```bash
./macos/install.sh
```

## 🔧 Funzionalità macOS

### Notifiche Automatiche

OffLiner invia automaticamente notifiche macOS quando:
- Il download è completato
- Si verificano errori critici

Le notifiche includono statistiche e aprono automaticamente Finder nella directory di output.

### Completamento Automatico

Dopo l'installazione, zsh completa automaticamente:
- Comandi (`offliner --`)
- Opzioni (`--url`, `--output-dir`, ecc.)
- Percorsi di directory

### Quick Action Finder

1. Seleziona un URL in qualsiasi applicazione
2. Clic destro → "Download with OffLiner"
3. Il download parte automaticamente

**Nota**: Dopo l'installazione, riavvia Finder per attivare la Quick Action:
```bash
killall Finder
```

### Alias Utili

Dopo il setup, sono disponibili questi alias:
- `off` → `offliner`
- `offline` → `offliner --output-dir ~/Downloads/OffLiner`

## 📂 Struttura Installazione

```
/usr/local/bin/offliner          # Script principale
/usr/local/share/zsh/site-functions/_offliner  # Completamento
~/Library/Services/Download with OffLiner.workflow  # Quick Action
```

## 🗑️ Disinstallazione

```bash
./macos/uninstall.sh
```

Questo rimuove:
- Script principale
- Completamento automatico
- Quick Action Finder

**Nota**: Le dipendenze Perl installate con cpanm non vengono rimosse automaticamente.

## 🔍 Verifica Installazione

```bash
# Verifica che offliner sia installato
which offliner

# Testa il completamento automatico
offliner --<TAB>

# Verifica Quick Action
# Vai in Finder → Servizi → Dovresti vedere "Download with OffLiner"
```

## 🐛 Risoluzione Problemi

### offliner non trovato

```bash
# Aggiungi al PATH
export PATH="/usr/local/bin:$PATH"

# Aggiungi permanentemente a ~/.zshrc
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Completamento automatico non funziona

```bash
# Verifica che il file sia installato
ls -la /usr/local/share/zsh/site-functions/_offliner

# Ricarica zsh
exec zsh
```

### Quick Action non appare

```bash
# Riavvia Finder
killall Finder

# Verifica che sia installata
ls -la ~/Library/Services/Download\ with\ OffLiner.workflow
```

### Notifiche non funzionano

Verifica le impostazioni di Sistema → Notifiche → Terminal (o l'app che stai usando).

## 📝 Note Tecniche

- **Perl**: Richiede Perl 5.14+ (incluso in macOS)
- **cpanm**: Installato automaticamente se mancante
- **Permessi**: Alcune operazioni richiedono `sudo`
- **Compatibilità**: Testato su macOS 10.15+ (Catalina e successivi)

## 🤝 Contribuire

Per migliorare l'integrazione macOS:
1. Testa su diverse versioni di macOS
2. Segnala problemi o suggerimenti
3. Contribuisci miglioramenti

