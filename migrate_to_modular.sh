#!/bin/bash
# Migration Script for Existing Fresh VHost Setups

echo "Migrating to Modular Fresh VHost System"
echo "======================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Backup existing monolithic script
if [[ -f "$SCRIPT_DIR/add_fresh_vhost_old.sh" ]]; then
    timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$SCRIPT_DIR/add_fresh_vhost_old.sh" "$SCRIPT_DIR/add_fresh_vhost_old_backup_$timestamp.sh"
    echo "✓ Backed up old script"
fi

# Move existing vhost files to new structure
OLD_VHOST_DIR="$SCRIPT_DIR/../vhost"
NEW_VHOST_DIR="$SCRIPT_DIR/../vhost/fresh"

if [[ -d "$OLD_VHOST_DIR" ]] && [[ ! -d "$NEW_VHOST_DIR" ]]; then
    mkdir -p "$NEW_VHOST_DIR"
    
    # Move fresh vhost files
    if ls "$OLD_VHOST_DIR"/*_fresh_vhost 1> /dev/null 2>&1; then
        mv "$OLD_VHOST_DIR"/*_fresh_vhost "$NEW_VHOST_DIR/"
        echo "✓ Moved fresh vhost files to new directory"
    fi
fi

echo "✓ Migration completed"
echo ""
echo "Run setup_modular.sh to complete the setup"
