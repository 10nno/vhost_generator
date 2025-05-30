#!/bin/bash
# Fresh VHost Management System Installer

echo "Installing Fresh VHost Management System"
echo "======================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR/tools/add_fresh_vhost.sh"
chmod +x "$SCRIPT_DIR/tools/setup_modular.sh"

if [[ -f "$SCRIPT_DIR/ssl_manager.sh" ]]; then
    chmod +x "$SCRIPT_DIR/ssl_manager.sh"
    echo "✓ SSL manager script permissions set"
fi

# Make function files executable
if [[ -d "$SCRIPT_DIR/functions" ]]; then
    chmod +x "$SCRIPT_DIR/functions"/*.sh 2>/dev/null
    echo "✓ Function files permissions set"
fi

echo "✓ Script permissions configured"

# Create symlink in /usr/local/bin if running as root
if [[ $EUID -eq 0 ]]; then
    ln -sf "$SCRIPT_DIR/add_fresh_vhost.sh" /usr/local/bin/fresh-vhost
    echo "✓ Created system-wide command: fresh-vhost"
    echo "  You can now use 'fresh-vhost' from anywhere"
else
    echo "ℹ Run as root to install system-wide command"
    echo "  sudo $0"
fi

echo ""
echo "✓ Installation complete"
echo ""
echo "Usage:"
echo "  $SCRIPT_DIR/add_fresh_vhost.sh        # Interactive mode"
echo "  $SCRIPT_DIR/add_fresh_vhost.sh help   # Show help"
if [[ $EUID -eq 0 ]]; then
    echo "  fresh-vhost                           # System-wide command"
fi
echo ""
echo "Next steps:"
echo "1. Ensure your database file exists at: ../database/domains_db.sh"
echo "2. Configure SSL credentials if needed"
echo "3. Run: $SCRIPT_DIR/add_fresh_vhost.sh"
