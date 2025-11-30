#!/bin/bash

# OffLiner - Setup automatico per macOS
# Questo script configura tutto per un uso immediato su macOS

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🍎 OffLiner - Setup Automatico macOS"
echo "===================================="
echo ""

# Verifica macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Errore: Questo script è solo per macOS"
    exit 1
fi

# Esegui installazione
echo "🚀 Avvio installazione..."
"$SCRIPT_DIR/install.sh"

# Configura notifiche (se supportato)
echo ""
echo "🔔 Configurazione notifiche macOS..."
if command -v osascript &> /dev/null; then
    # Testa le notifiche
    osascript -e 'display notification "OffLiner installato con successo!" with title "OffLiner" sound name "Glass"' 2>/dev/null || true
    echo "✓ Notifiche configurate"
else
    echo "⚠️  osascript non disponibile"
fi

# Apri Finder nella directory di output di default
echo ""
echo "📂 Configurazione directory di output..."
DEFAULT_OUTPUT="$HOME/Downloads/OffLiner"
mkdir -p "$DEFAULT_OUTPUT"
echo "✓ Directory di output predefinita: $DEFAULT_OUTPUT"

# Crea alias per uso rapido
echo ""
echo "🔗 Creazione alias..."
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q "alias offliner" "$HOME/.zshrc"; then
        echo "" >> "$HOME/.zshrc"
        echo "# OffLiner aliases" >> "$HOME/.zshrc"
        echo "alias off='offliner'" >> "$HOME/.zshrc"
        echo "alias offline='offliner --output-dir \"$DEFAULT_OUTPUT\"'" >> "$HOME/.zshrc"
        echo "✓ Alias aggiunti a ~/.zshrc"
    fi
elif [ -f "$HOME/.bash_profile" ]; then
    if ! grep -q "alias offliner" "$HOME/.bash_profile"; then
        echo "" >> "$HOME/.bash_profile"
        echo "# OffLiner aliases" >> "$HOME/.bash_profile"
        echo "alias off='offliner'" >> "$HOME/.bash_profile"
        echo "alias offline='offliner --output-dir \"$DEFAULT_OUTPUT\"'" >> "$HOME/.bash_profile"
        echo "✓ Alias aggiunti a ~/.bash_profile"
    fi
fi

echo ""
echo "🎉 Setup completato!"
echo ""
echo "📋 Prossimi passi:"
echo "  1. Riavvia il terminale o esegui: source ~/.zshrc"
echo "  2. Prova: offliner --url https://example.com"
echo "  3. Oppure usa l'alias: offline --url https://example.com"
echo ""
echo "💡 Funzionalità macOS attive:"
echo "  ✓ Notifiche al completamento download"
echo "  ✓ Completamento automatico comandi"
echo "  ✓ Quick Action Finder (riavvia Finder)"
echo "  ✓ Integrazione nativa macOS"
echo ""

