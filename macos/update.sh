#!/bin/bash

# OffLiner - Script di aggiornamento per macOS

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔄 OffLiner - Aggiornamento"
echo "=========================="
echo ""

# Verifica che siamo su macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Errore: Questo script è solo per macOS"
    exit 1
fi

# Verifica versione attuale
CURRENT_VERSION="1.0.0"
if command -v offliner &> /dev/null; then
    CURRENT_VERSION=$(offliner --check-update 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "1.0.0")
fi

echo "Versione attuale: $CURRENT_VERSION"
echo ""

# Verifica aggiornamenti disponibili
echo "🔍 Verifica aggiornamenti disponibili..."
if command -v offliner &> /dev/null; then
    offliner --check-update
    echo ""
    read -p "Vuoi aggiornare? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Aggiornamento annullato."
        exit 0
    fi
else
    echo "⚠️  OffLiner non trovato. Esegui install.sh prima."
    exit 1
fi

# Backup configurazione
if [ -f "$HOME/.config/offliner/config.json" ]; then
    echo "💾 Backup configurazione..."
    cp "$HOME/.config/offliner/config.json" "$HOME/.config/offliner/config.json.backup"
    echo "✓ Backup salvato"
fi

# Aggiorna da git (se disponibile)
if [ -d "$PROJECT_ROOT/.git" ]; then
    echo "📥 Aggiornamento da git..."
    cd "$PROJECT_ROOT"
    git pull origin main || git pull origin master || {
        echo "⚠️  Impossibile aggiornare da git. Continua con reinstallazione..."
    }
fi

# Reinstalla
echo ""
echo "🔧 Reinstallazione..."
"$SCRIPT_DIR/install.sh"

echo ""
echo "✅ Aggiornamento completato!"
echo ""
echo "Per verificare la versione:"
echo "  offliner --check-update"

