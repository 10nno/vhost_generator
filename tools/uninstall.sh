#!/bin/bash
# Fresh VHost Management System Uninstaller

echo "Uninstalling Fresh VHost Management System"
echo "=========================================="

# Remove system-wide command if it exists
if [[ -L "/usr/local/bin/fresh-vhost" ]]; then
    rm "/usr/local/bin/fresh-vhost"
    echo "✓ Removed system-wide command"
fi

echo "✓ Uninstallation complete"
echo ""
echo "Note: VHost files and backups have been preserved"
echo "Remove manually if needed:"
echo "  - VHost files: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/vhost/fresh/"
echo "  - Backups: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backup/"
echo "  - Templates: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/template/"
echo "  - Logs: $(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs/"
