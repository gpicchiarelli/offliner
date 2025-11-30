#!/bin/bash

# OffLiner - Installer per macOS
# Questo script installa OffLiner e tutte le integrazioni macOS

set -euo pipefail

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# File di log
LOG_FILE="${HOME}/.offliner_install.log"
INSTALLED_FILES="${HOME}/.offliner_installed_files.txt"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$LOG_FILE"
}

# Funzione per rollback
rollback() {
    warning "Errore durante l'installazione. Eseguo rollback..."
    if [ -f "$INSTALLED_FILES" ]; then
        while IFS= read -r file; do
            if [ -e "$file" ]; then
                log "Rimuovo: $file"
                sudo rm -rf "$file" 2>/dev/null || rm -rf "$file" 2>/dev/null || true
            fi
        done < "$INSTALLED_FILES"
        rm -f "$INSTALLED_FILES"
    fi
    error "Installazione fallita. Rollback completato."
}

trap rollback ERR

# Inizializza log
> "$LOG_FILE"
> "$INSTALLED_FILES"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/usr/local/bin"
COMPLETION_DIR="/usr/local/share/zsh/site-functions"
QUICK_ACTIONS_DIR="$HOME/Library/Services"
CONFIG_DIR="$HOME/.config/offliner"

log "🍎 OffLiner - Installazione per macOS"
log "======================================"
log ""

# Verifica che siamo su macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "Questo script è solo per macOS"
fi

# Verifica versione macOS minima (10.15)
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
MACOS_MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)
if [ "$MACOS_MAJOR" -lt 10 ] || ([ "$MACOS_MAJOR" -eq 10 ] && [ "$MACOS_MINOR" -lt 15 ]); then
    error "Richiede macOS 10.15 o superiore. Versione attuale: $MACOS_VERSION"
fi
success "macOS $MACOS_VERSION rilevato"

# Verifica Perl e versione
if ! command -v perl &> /dev/null; then
    error "Perl non trovato. macOS include Perl, verifica la tua installazione."
fi

PERL_VERSION=$(perl -v | grep -oE 'v[0-9]+\.[0-9]+' | head -1 | sed 's/v//')
PERL_MAJOR=$(echo "$PERL_VERSION" | cut -d. -f1)
PERL_MINOR=$(echo "$PERL_VERSION" | cut -d. -f2)

if [ "$PERL_MAJOR" -lt 5 ] || ([ "$PERL_MAJOR" -eq 5 ] && [ "$PERL_MINOR" -lt 14 ]); then
    error "Richiede Perl 5.14 o superiore. Versione attuale: $PERL_VERSION"
fi
success "Perl $PERL_VERSION trovato"

# Verifica supporto threads
if ! perl -e 'use threads;' 2>/dev/null; then
    error "Perl non supporta threads. Installa una versione di Perl con supporto threads."
fi
success "Perl supporta threads"

# Verifica spazio disco (minimo 100MB)
AVAILABLE_SPACE=$(df -m "$HOME" | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_SPACE" -lt 100 ]; then
    error "Spazio disco insufficiente. Richiesto: 100MB, Disponibile: ${AVAILABLE_SPACE}MB"
fi
success "Spazio disco sufficiente: ${AVAILABLE_SPACE}MB disponibili"

# Verifica connessione internet
if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null && ! ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
    warning "Connessione internet non rilevata. L'installazione delle dipendenze potrebbe fallire."
    read -p "Vuoi continuare comunque? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
else
    success "Connessione internet verificata"
fi

# Verifica permessi sudo
log "Verifica permessi amministratore..."
if ! sudo -n true 2>/dev/null; then
    log "Richiesta password amministratore..."
    sudo -v
    # Mantieni sudo attivo
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi
success "Permessi amministratore verificati"

# Verifica cpanm
if ! command -v cpanm &> /dev/null; then
    log "📦 Installazione di cpanminus (cpanm)..."
    if command -v curl &> /dev/null; then
        curl -L https://cpanmin.us | perl - App::cpanminus || error "Installazione cpanm fallita"
    else
        error "curl non trovato. Installa curl o cpanm manualmente."
    fi
fi
success "cpanm trovato"

# Verifica dipendenze prima di installare
log ""
log "📦 Verifica dipendenze Perl..."
cd "$PROJECT_ROOT"

# Lista dipendenze critiche
CRITICAL_DEPS=("LWP::UserAgent" "URI" "threads" "Thread::Queue" "Thread::Semaphore")
MISSING_DEPS=()

for dep in "${CRITICAL_DEPS[@]}"; do
    if ! perl -M"$dep" -e 1 2>/dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    log "Dipendenze mancanti: ${MISSING_DEPS[*]}"
    log "Installazione dipendenze..."
    cpanm --notest --quiet --installdeps . || error "Installazione dipendenze fallita"
    success "Dipendenze installate"
else
    success "Tutte le dipendenze critiche sono presenti"
fi

# Crea directory di installazione
log ""
log "📁 Creazione directory di installazione..."
sudo mkdir -p "$INSTALL_DIR" || error "Impossibile creare $INSTALL_DIR"
echo "$INSTALL_DIR/offliner" >> "$INSTALLED_FILES"
sudo mkdir -p "$COMPLETION_DIR" || error "Impossibile creare $COMPLETION_DIR"
echo "$COMPLETION_DIR/_offliner" >> "$INSTALLED_FILES"
mkdir -p "$QUICK_ACTIONS_DIR" || error "Impossibile creare $QUICK_ACTIONS_DIR"
mkdir -p "$CONFIG_DIR" || error "Impossibile creare $CONFIG_DIR"
echo "$QUICK_ACTIONS_DIR/Download with OffLiner.workflow" >> "$INSTALLED_FILES"
echo "$CONFIG_DIR" >> "$INSTALLED_FILES"
success "Directory create"

# Installa lo script principale
log "📝 Installazione script principale..."
if [ ! -f "$PROJECT_ROOT/offliner.pl" ]; then
    error "File offliner.pl non trovato in $PROJECT_ROOT"
fi
sudo cp "$PROJECT_ROOT/offliner.pl" "$INSTALL_DIR/offliner" || error "Copia script fallita"
sudo chmod +x "$INSTALL_DIR/offliner" || error "Impossibile rendere eseguibile"
success "Script principale installato"

# Verifica installazione script
if [ ! -x "$INSTALL_DIR/offliner" ]; then
    error "Script installato ma non eseguibile"
fi

# Installa completamento automatico
log "⌨️  Installazione completamento automatico zsh..."
if [ -f "$PROJECT_ROOT/macos/_offliner" ]; then
    sudo cp "$PROJECT_ROOT/macos/_offliner" "$COMPLETION_DIR/_offliner" || error "Copia completamento fallita"
    sudo chmod 644 "$COMPLETION_DIR/_offliner" || error "Impossibile impostare permessi"
    success "Completamento automatico installato"
else
    warning "File completamento non trovato, saltato"
fi

# Installa Quick Action per Finder
log "🔧 Installazione Quick Action per Finder..."
if [ -d "$PROJECT_ROOT/macos/Download with OffLiner.workflow" ]; then
    cp -R "$PROJECT_ROOT/macos/Download with OffLiner.workflow" "$QUICK_ACTIONS_DIR/" || error "Copia Quick Action fallita"
    success "Quick Action installata. Riavvia Finder per attivarla."
else
    warning "Quick Action non trovata, saltata"
fi

# Crea file di configurazione default
log "⚙️  Creazione configurazione default..."
cat > "$CONFIG_DIR/config.json" <<EOF
{
  "default_output_dir": "$HOME/Downloads/OffLiner",
  "default_max_depth": 50,
  "default_max_threads": 10,
  "default_max_retries": 3,
  "notifications_enabled": true,
  "open_finder_on_complete": true,
  "version": "1.0.0"
}
EOF
success "Configurazione creata"

# Verifica installazione
log ""
log "✅ Verifica installazione..."
if command -v offliner &> /dev/null; then
    OFFLINER_VERSION=$(offliner --help 2>&1 | head -1 || echo "installato")
    success "offliner installato in: $(which offliner)"
else
    warning "offliner potrebbe non essere nel PATH"
fi

# Aggiungi al PATH se necessario
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log ""
    log "⚠️  $INSTALL_DIR non è nel tuo PATH"
    
    # Prova ad aggiungere automaticamente
    SHELL_RC=""
    if [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -f "$HOME/.zprofile" ]; then
        SHELL_RC="$HOME/.zprofile"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_RC="$HOME/.bash_profile"
    elif [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "export PATH=\"$INSTALL_DIR:\$PATH\"" "$SHELL_RC"; then
            echo "" >> "$SHELL_RC"
            echo "# OffLiner" >> "$SHELL_RC"
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$SHELL_RC"
            success "PATH aggiunto a $SHELL_RC"
            # Esegui source immediatamente se possibile
            if [ -n "$ZSH_VERSION" ]; then
                export PATH="$INSTALL_DIR:$PATH"
            elif [ -n "$BASH_VERSION" ]; then
                export PATH="$INSTALL_DIR:$PATH"
            fi
        fi
    else
        log "Aggiungi manualmente al tuo file di configurazione shell:"
        log "  export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
fi

# Test notifiche
log ""
log "🔔 Test notifiche macOS..."
if command -v osascript &> /dev/null; then
    osascript -e 'display notification "OffLiner installato con successo!" with title "OffLiner" sound name "Glass"' 2>/dev/null && success "Notifiche funzionanti" || warning "Notifiche potrebbero non funzionare"
else
    warning "osascript non disponibile"
fi

log ""
success "🎉 Installazione completata!"
log ""
log "Per usare OffLiner:"
log "  offliner --url https://example.com"
log ""
log "Per vedere tutte le opzioni:"
log "  offliner --help"
log ""
log "💡 Suggerimenti:"
log "  - Usa il completamento automatico: digita 'offliner --' e premi TAB"
log "  - Usa la Quick Action: seleziona un URL nel Finder e clicca destro"
log "  - Le notifiche macOS ti avviseranno quando il download è completato"
log "  - Configurazione salvata in: $CONFIG_DIR/config.json"
log ""
log "📋 Log installazione: $LOG_FILE"
log ""

# Rimuovi trap di rollback (installazione completata)
trap - ERR
