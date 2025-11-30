#!/bin/bash

# OffLiner - Installer per macOS
# Questo script installa OffLiner e tutte le integrazioni macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="/usr/local/bin"
COMPLETION_DIR="/usr/local/share/zsh/site-functions"
QUICK_ACTIONS_DIR="$HOME/Library/Services"

echo "🍎 OffLiner - Installazione per macOS"
echo "======================================"
echo ""

# Verifica che siamo su macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Errore: Questo script è solo per macOS"
    exit 1
fi

# Verifica Perl
if ! command -v perl &> /dev/null; then
    echo "❌ Errore: Perl non trovato. macOS include Perl, verifica la tua installazione."
    exit 1
fi

PERL_VERSION=$(perl -v | grep -oP 'v\K[0-9]+\.[0-9]+' | head -1)
echo "✓ Perl trovato: $PERL_VERSION"

# Verifica cpanm
if ! command -v cpanm &> /dev/null; then
    echo "📦 Installazione di cpanminus (cpanm)..."
    if command -v curl &> /dev/null; then
        curl -L https://cpanmin.us | perl - App::cpanminus
    else
        echo "❌ Errore: curl non trovato. Installa curl o cpanm manualmente."
        exit 1
    fi
fi

echo "✓ cpanm trovato"

# Installa dipendenze
echo ""
echo "📦 Installazione dipendenze Perl..."
cd "$PROJECT_ROOT"
cpanm --notest --quiet --installdeps . || {
    echo "⚠️  Alcune dipendenze potrebbero non essere state installate. Continuo comunque..."
}

# Crea directory di installazione
echo ""
echo "📁 Creazione directory di installazione..."
sudo mkdir -p "$INSTALL_DIR"
sudo mkdir -p "$COMPLETION_DIR"
mkdir -p "$QUICK_ACTIONS_DIR"

# Installa lo script principale
echo "📝 Installazione script principale..."
sudo cp "$PROJECT_ROOT/offliner.pl" "$INSTALL_DIR/offliner"
sudo chmod +x "$INSTALL_DIR/offliner"

# Installa completamento automatico
echo "⌨️  Installazione completamento automatico zsh..."
if [ -f "$PROJECT_ROOT/macos/_offliner" ]; then
    sudo cp "$PROJECT_ROOT/macos/_offliner" "$COMPLETION_DIR/_offliner"
    sudo chmod 644 "$COMPLETION_DIR/_offliner"
fi

# Installa Quick Action per Finder
echo "🔧 Installazione Quick Action per Finder..."
if [ -f "$PROJECT_ROOT/macos/Download with OffLiner.workflow" ]; then
    cp -R "$PROJECT_ROOT/macos/Download with OffLiner.workflow" "$QUICK_ACTIONS_DIR/"
    echo "✓ Quick Action installata. Riavvia Finder per attivarla."
fi

# Verifica installazione
echo ""
echo "✅ Verifica installazione..."
if command -v offliner &> /dev/null; then
    OFFLINER_VERSION=$(offliner --help 2>&1 | head -1 || echo "installato")
    echo "✓ offliner installato in: $(which offliner)"
else
    echo "⚠️  offliner potrebbe non essere nel PATH"
fi

# Aggiungi al PATH se necessario
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  $INSTALL_DIR non è nel tuo PATH"
    echo "Aggiungi questa riga al tuo ~/.zshrc o ~/.bash_profile:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    echo ""
    read -p "Vuoi aggiungerlo automaticamente ora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        if [ -f "$HOME/.zshrc" ]; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.zshrc"
            echo "✓ Aggiunto a ~/.zshrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bash_profile"
            echo "✓ Aggiunto a ~/.bash_profile"
        fi
        echo "Esegui 'source ~/.zshrc' o riavvia il terminale per applicare le modifiche."
    fi
fi

echo ""
echo "🎉 Installazione completata!"
echo ""
echo "Per usare OffLiner:"
echo "  offliner --url https://example.com"
echo ""
echo "Per vedere tutte le opzioni:"
echo "  offliner --help"
echo ""
echo "💡 Suggerimenti:"
echo "  - Usa il completamento automatico: digita 'offliner --' e premi TAB"
echo "  - Usa la Quick Action: seleziona un URL nel Finder e clicca destro"
echo "  - Le notifiche macOS ti avviseranno quando il download è completato"
echo ""

