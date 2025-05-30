#!/bin/bash

# Setup Modular Structure Script
# File: setup_modular.sh
# Sets up the modular fresh vhost management system

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/functions"

echo "Setting up Modular Fresh VHost Management System"
echo "================================================"
echo ""
echo "Script Directory: $SCRIPT_DIR"
echo "Main Directory: $MAIN_DIR"
echo "Functions Directory: $FUNCTIONS_DIR"
echo ""

# Create functions directory
if [[ ! -d "$FUNCTIONS_DIR" ]]; then
    mkdir -p "$FUNCTIONS_DIR"
    echo "✓ Created functions directory: $FUNCTIONS_DIR"
else
    echo "✓ Functions directory already exists"
fi

# Create directory structure
DIRECTORIES=(
    "$MAIN_DIR/vhost/fresh"
    "$MAIN_DIR/template"
    "$MAIN_DIR/backup/vhosts"
    "$MAIN_DIR/logs"
)

echo ""
echo "Creating directory structure..."
echo "=============================="

for dir in "${DIRECTORIES[@]}"; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "✓ Created: $dir"
    else
        echo "✓ Exists: $dir"
    fi
done

# Function files to create/move
FUNCTION_FILES=(
    "core_functions.sh:Core functions (init, template, basic operations)"
    "nginx_functions.sh:Nginx management functions"
    "single_operations.sh:Single domain operations"
    "bulk_functions.sh:Bulk operations"
    "interactive_functions.sh:Interactive menus and UI"
)

echo ""
echo "Function Files Status"
echo "===================="

for file_info in "${FUNCTION_FILES[@]}"; do
    IFS=':' read -ra PARTS <<< "$file_info"
    filename="${PARTS[0]}"
    description="${PARTS[1]}"
    
    functions_file="$FUNCTIONS_DIR/$filename"
    script_file="$SCRIPT_DIR/$filename"
    
    printf "%-25s " "$filename"
    
    if [[ -f "$functions_file" ]]; then
        echo "✓ Available in functions/ - $description"
    elif [[ -f "$script_file" ]]; then
        echo "⚠ Available in script dir - $description"
        echo "  Consider moving to functions/ directory"
    else
        echo "✗ Missing - $description"
        echo "  Please create this file with the appropriate functions"
    fi
done

# Check main script
echo ""
echo "Main Script Status"
echo "=================="

MAIN_SCRIPT="$SCRIPT_DIR/add_fresh_vhost.sh"
if [[ -f "$MAIN_SCRIPT" ]]; then
    echo "✓ Main script exists: $MAIN_SCRIPT"
else
    echo "✗ Main script missing: $MAIN_SCRIPT"
fi

# Check SSL manager
SSL_MANAGER="$SCRIPT_DIR/ssl_manager.sh"
if [[ -f "$SSL_MANAGER" ]]; then
    echo "✓ SSL manager exists: $SSL_MANAGER"
else
    echo "⚠ SSL manager missing: $SSL_MANAGER"
    echo "  SSL operations will use legacy mode"
fi

# Check database
echo ""
echo "Database Status"
echo "==============="

DATABASE_FILE="$MAIN_DIR/database/domains_db.sh"
if [[ -f "$DATABASE_FILE" ]]; then
    echo "✓ Database file exists: $DATABASE_FILE"
    
    # Test if database functions are available
    if source "$DATABASE_FILE" 2>/dev/null; then
        if declare -f get_all_brands >/dev/null 2>&1; then
            brand_count=$(get_all_brands 2>/dev/null | wc -l)
            echo "✓ Database functions loaded ($brand_count brands available)"
        else
            echo "⚠ Database file exists but functions not available"
        fi
    else
        echo "⚠ Database file exists but cannot be sourced"
    fi
else
    echo "✗ Database file missing: $DATABASE_FILE"
    echo "  Please ensure the database file exists with brand/domain data"
fi

# Check template
echo ""
echo "Template Status"
echo "==============="

TEMPLATE_FILE="$MAIN_DIR/template/fresh_template"
if [[ -f "$TEMPLATE_FILE" ]]; then
    echo "✓ Template file exists: $TEMPLATE_FILE"
else
    echo "⚠ Template file missing: $TEMPLATE_FILE"
    echo "  Template will be created automatically when needed"
fi

# Check nginx directories
echo ""
echo "Nginx Status"
echo "============"

if [[ -d "/etc/nginx/sites-available" ]]; then
    echo "✓ Nginx sites-available directory exists"
else
    echo "⚠ Nginx sites-available directory not found"
fi

if [[ -d "/etc/nginx/sites-enabled" ]]; then
    echo "✓ Nginx sites-enabled directory exists"
else
    echo "⚠ Nginx sites-enabled directory not found"
fi

if command -v nginx >/dev/null 2>&1; then
    echo "✓ Nginx command available"
else
    echo "⚠ Nginx command not found"
fi

# Check SSL prerequisites
echo ""
echo "SSL Prerequisites"
echo "================="

if command -v certbotcf >/dev/null 2>&1; then
    echo "✓ certbotcf command available"
else
    echo "⚠ certbotcf command not found"
    echo "  Install certbot-cloudflare for SSL functionality"
fi

if [[ -f "/etc/letsencrypt/cloudflare.ini" ]]; then
    echo "✓ Cloudflare credentials file exists"
else
    echo "⚠ Cloudflare credentials file not found"
    echo "  Create /etc/letsencrypt/cloudflare.ini for SSL functionality"
fi

if [[ -d "/etc/letsencrypt/live" ]]; then
    echo "✓ Let's Encrypt directory exists"
else
    echo "⚠ Let's Encrypt directory not found"
fi

# Create example configuration files
echo ""
echo "Creating Example Files"
echo "====================="

# Create example function file if none exist
EXAMPLE_CORE="$FUNCTIONS_DIR/core_functions.sh"
if [[ ! -f "$EXAMPLE_CORE" ]]; then
    cat > "$EXAMPLE_CORE" << 'EOF'
#!/bin/bash
# Core Fresh VHost Functions
# This is an example file - replace with actual functions

# Function to create directories
init_directories() {
    [[ ! -d "$VHOST_DIR" ]] && mkdir -p "$VHOST_DIR"
    [[ ! -d "$TEMPLATE_DIR" ]] && mkdir -p "$TEMPLATE_DIR"
    echo "✓ Directories initialized"
}

# Function to create template
create_template() {
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "Creating fresh vhost template..."
        # Template creation code here
    fi
}

# Add other core functions here...
EOF
    echo "✓ Created example core functions file"
else
    echo "⚠ Core functions file already exists"
fi

# Create README file
README_FILE="$FUNCTIONS_DIR/README.md"
if [[ ! -f "$README_FILE" ]]; then
    cat > "$README_FILE" << 'EOF'
# Fresh VHost Functions Directory

This directory contains modular function files for the fresh vhost management system.

## Function Files:

- `core_functions.sh` - Core functionality (init, template, basic operations)
- `nginx_functions.sh` - Nginx management (symlinks, reload, status)
- `single_operations.sh` - Single domain operations (create, update, clone)
- `bulk_functions.sh` - Bulk operations (bulk create, delete, backup)
- `interactive_functions.sh` - Interactive menus and user interface

## Usage:

These files are automatically sourced by the main script `add_fresh_vhost.sh`.

## Adding New Functions:

1. Create or edit the appropriate function file
2. Add your function following bash best practices
3. Test the function independently
4. Update this README if adding new files

## Dependencies:

- Database file: `../database/domains_db.sh`
- Template file: `../template/fresh_template`
- Main script: `../add_fresh_vhost.sh`

## File Structure:

```
project/
├── tools/
│   ├── add_fresh_vhost.sh          # Main script
│   ├── ssl_manager.sh              # SSL management
│   ├── setup_modular.sh            # This setup script
│   └── functions/                  # Function modules
│       ├── core_functions.sh
│       ├── nginx_functions.sh
│       ├── single_operations.sh
│       ├── bulk_functions.sh
│       └── interactive_functions.sh
├── database/
│   └── domains_db.sh               # Domain database
├── template/
│   └── fresh_template              # Nginx template
├── vhost/
│   └── fresh/                      # Generated vhost files
├── backup/
│   └── vhosts/                     # Backup storage
└── logs/                           # Log files
```
EOF
    echo "✓ Created README file"
else
    echo "⚠ README file already exists"
fi

# Create installation script
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    cat > "$INSTALL_SCRIPT" << 'EOF'
#!/bin/bash
# Fresh VHost Management System Installer

echo "Installing Fresh VHost Management System"
echo "======================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
echo "Making scripts executable..."
chmod +x "$SCRIPT_DIR/add_fresh_vhost.sh"
chmod +x "$SCRIPT_DIR/setup_modular.sh"

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
EOF
    chmod +x "$INSTALL_SCRIPT"
    echo "✓ Created installation script"
else
    echo "⚠ Installation script already exists"
fi

# Create uninstall script
UNINSTALL_SCRIPT="$SCRIPT_DIR/uninstall.sh"
if [[ ! -f "$UNINSTALL_SCRIPT" ]]; then
    cat > "$UNINSTALL_SCRIPT" << 'EOF'
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
EOF
    chmod +x "$UNINSTALL_SCRIPT"
    echo "✓ Created uninstallation script"
else
    echo "⚠ Uninstallation script already exists"
fi

# Create environment configuration file
ENV_CONFIG="$SCRIPT_DIR/.env.example"
if [[ ! -f "$ENV_CONFIG" ]]; then
    cat > "$ENV_CONFIG" << 'EOF'
# Fresh VHost Management System Configuration
# Copy this file to .env and customize as needed

# Directories
VHOST_DIR="$MAIN_DIR/vhost/fresh"
TEMPLATE_DIR="$MAIN_DIR/template"
BACKUP_DIR="$MAIN_DIR/backup/vhosts"
LOG_DIR="$MAIN_DIR/logs"

# SSL Configuration
CLOUDFLARE_CREDENTIALS="/etc/letsencrypt/cloudflare.ini"
CERTBOT_CMD="certbotcf"
LETSENCRYPT_DIR="/etc/letsencrypt/live"

# Nginx Configuration
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

# Default Settings
DEFAULT_SSL_ENABLED="yes"
DEFAULT_WILDCARD_SSL="yes"
DEFAULT_AUTO_SYMLINK="yes"
DEFAULT_AUTO_RELOAD="ask"

# Backup Settings
BACKUP_RETENTION_DAYS="30"
AUTO_BACKUP_BEFORE_BULK="yes"

# Logging
LOG_LEVEL="INFO"  # DEBUG, INFO, WARNING, ERROR
LOG_ROTATION="daily"
EOF
    echo "✓ Created environment configuration example"
else
    echo "⚠ Environment configuration example already exists"
fi

# Create migration script for existing setups
MIGRATION_SCRIPT="$SCRIPT_DIR/migrate_to_modular.sh"
if [[ ! -f "$MIGRATION_SCRIPT" ]]; then
    cat > "$MIGRATION_SCRIPT" << 'EOF'
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
EOF
    chmod +x "$MIGRATION_SCRIPT"
    echo "✓ Created migration script"
else
    echo "⚠ Migration script already exists"
fi

# Final summary
echo ""
echo "Setup Summary"
echo "============="
echo ""

# Count available functions
available_functions=0
missing_functions=0

for file_info in "${FUNCTION_FILES[@]}"; do
    IFS=':' read -ra PARTS <<< "$file_info"
    filename="${PARTS[0]}"
    
    if [[ -f "$FUNCTIONS_DIR/$filename" ]] || [[ -f "$SCRIPT_DIR/$filename" ]]; then
        ((available_functions++))
    else
        ((missing_functions++))
    fi
done

echo "Function files: $available_functions available, $missing_functions missing"

if [[ -f "$MAIN_SCRIPT" ]]; then
    echo "✓ Main script ready"
else
    echo "✗ Main script missing"
fi

if [[ -f "$DATABASE_FILE" ]]; then
    echo "✓ Database ready"
else
    echo "✗ Database missing"
fi

# Check system readiness
readiness_score=0
total_checks=5

[[ $available_functions -eq 5 ]] && ((readiness_score++))
[[ -f "$MAIN_SCRIPT" ]] && ((readiness_score++))
[[ -f "$DATABASE_FILE" ]] && ((readiness_score++))
[[ -d "/etc/nginx/sites-enabled" ]] && ((readiness_score++))
[[ $(command -v nginx) ]] && ((readiness_score++))

echo ""
echo "System Readiness: $readiness_score/$total_checks"

if [[ $readiness_score -eq $total_checks ]]; then
    echo "🎉 System is ready to use!"
elif [[ $readiness_score -ge 3 ]]; then
    echo "⚠ System is mostly ready with minor issues"
else
    echo "❌ System needs attention before use"
fi

echo ""
echo "Next Steps:"
echo "==========="

step=1

if [[ $missing_functions -gt 0 ]]; then
    echo "$step. Create missing function files in $FUNCTIONS_DIR/"
    ((step++))
fi

if [[ ! -f "$DATABASE_FILE" ]]; then
    echo "$step. Create database file: $DATABASE_FILE"
    ((step++))
fi

if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "$step. Create main script: $MAIN_SCRIPT"
    ((step++))
fi

echo "$step. Run: $SCRIPT_DIR/install.sh (optional system-wide installation)"
((step++))

echo "$step. Test: $SCRIPT_DIR/add_fresh_vhost.sh help"
((step++))

echo "$step. Start using: $SCRIPT_DIR/add_fresh_vhost.sh"

echo ""
echo "Quick Start:"
echo "============"
echo "For interactive mode: $SCRIPT_DIR/add_fresh_vhost.sh"
echo "For help: $SCRIPT_DIR/add_fresh_vhost.sh help"
echo "For installation: $SCRIPT_DIR/install.sh"

echo ""
echo "Created Files:"
echo "=============="
echo "- Functions directory: $FUNCTIONS_DIR"
echo "- Installation script: $INSTALL_SCRIPT"
echo "- Uninstallation script: $UNINSTALL_SCRIPT"
echo "- Environment config: $ENV_CONFIG"
echo "- Migration script: $MIGRATION_SCRIPT"
echo "- README: $README_FILE"