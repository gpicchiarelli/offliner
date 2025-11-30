#!/bin/bash

# OffLiner - Disinstallazione per macOS

set -e

INSTALL_DIR="/usr/local/bin"
COMPLETION_DIR="/usr/local/share/zsh/site-functions"
QUICK_ACTIONS_DIR="$HOME/Library/Services"

echo "🍎 OffLiner - Disinstallazione"
echo "==============================="
echo ""

# Rimuovi script principale
if [ -f "$INSTALL_DIR/offliner" ]; then
    echo "🗑️  Rimozione script principale..."
    sudo rm -f "$INSTALL_DIR/offliner"
    echo "✓ Rimosso"
else
    echo "⚠️  Script principale non trovato"
fi

# Rimuovi completamento automatico
if [ -f "$COMPLETION_DIR/_offliner" ]; then
    echo "🗑️  Rimozione completamento automatico..."
    sudo rm -f "$COMPLETION_DIR/_offliner"
    echo "✓ Rimosso"
else
    echo "⚠️  Completamento automatico non trovato"
fi

# Rimuovi Quick Action
if [ -d "$QUICK_ACTIONS_DIR/Download with OffLiner.workflow" ]; then
    echo "🗑️  Rimozione Quick Action..."
    rm -rf "$QUICK_ACTIONS_DIR/Download with OffLiner.workflow"
    echo "✓ Rimossa"
else
    echo "⚠️  Quick Action non trovata"
fi

echo ""
echo "✅ Disinstallazione completata!"
echo ""
echo "Nota: Le dipendenze Perl installate con cpanm non vengono rimosse."
echo "Per rimuoverle manualmente, usa: cpanm --uninstall OffLiner"

