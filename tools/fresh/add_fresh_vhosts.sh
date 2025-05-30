#!/bin/bash

# Main Fresh VHost Script
# File: add_fresh_vhost.sh
# Modular fresh vhost management system

# Get the main project directory (parent of tools directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATABASE_DIR="$MAIN_DIR/database"
DATABASE_FILE="$DATABASE_DIR/domains_db.sh"
TEMPLATE_DIR="$MAIN_DIR/template"
TEMPLATE_FILE="$TEMPLATE_DIR/fresh_template"
VHOST_DIR="$MAIN_DIR/vhost/fresh"

# Source the database file
if [[ -f "$DATABASE_FILE" ]]; then
    source "$DATABASE_FILE"
else
    echo "Error: Database file not found at: $DATABASE_FILE"
    exit 1
fi

# Source modular function files
FUNCTIONS_DIR="$SCRIPT_DIR/functions"

# Create functions directory if it doesn't exist
[[ ! -d "$FUNCTIONS_DIR" ]] && mkdir -p "$FUNCTIONS_DIR"

# List of function files to source
FUNCTION_FILES=(
    "core_functions.sh"
    "nginx_functions.sh"
    "single_operations.sh"
    "bulk_functions.sh"
    "interactive_functions.sh"
)

# Source each function file
for func_file in "${FUNCTION_FILES[@]}"; do
    local_file="$FUNCTIONS_DIR/$func_file"
    script_dir_file="$SCRIPT_DIR/$func_file"
    
    # Try to source from functions directory first, then script directory
    if [[ -f "$local_file" ]]; then
        source "$local_file"
    elif [[ -f "$script_dir_file" ]]; then
        source "$script_dir_file"
    else
        echo "Warning: Function file not found: $func_file"
        echo "Expected locations:"
        echo "  - $local_file"
        echo "  - $script_dir_file"
    fi
done

# Show usage information
show_usage() {
    echo "Fresh VHost Management System"
    echo "============================"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  create <brand> <domain> [main_domain] [ssl]  - Create single vhost"
    echo "  bulk                                         - Bulk create all fresh vhosts"
    echo "  bulk-brand                                   - Bulk create for specific brand"
    echo "  delete <domain>                              - Delete single vhost"
    echo "  bulk-delete                                  - Bulk delete vhosts"
    echo "  list                                         - List all fresh vhosts"
    echo "  status                                       - Show vhost status"
    echo "  enable <domain>                              - Enable vhost"
    echo "  disable <domain>                             - Disable vhost"
    echo "  bulk-enable                                  - Enable all vhosts"
    echo "  bulk-disable                                 - Disable all vhosts"
    echo "  update <domain> [new_main_domain]            - Update existing vhost"
    echo "  clone <source> <target> [main_domain]        - Clone vhost"
    echo "  validate <domain>                            - Validate vhost configuration"
    echo "  info <domain>                                - Show vhost information"
    echo "  backup [backup_dir]                          - Backup all vhosts"
    echo "  restore [backup_dir]                         - Restore from backup"
    echo "  nginx-test                                    - Test nginx configuration"
    echo "  nginx-reload                                 - Reload nginx"
    echo "  nginx-status                                 - Check nginx status"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Interactive mode"
    echo "  $0 create MILDCASINO new-domain.com         # Create single vhost"
    echo "  $0 bulk                                      # Bulk create all"
    echo "  $0 list                                      # List vhosts"
    echo "  $0 enable new-domain.com                     # Enable vhost"
    echo "  $0 validate new-domain.com                   # Validate config"
    echo "  $0 backup /path/to/backup                    # Backup vhosts"
    echo ""
    echo "For interactive mode, run without arguments."
}

# Main execution logic
main() {
    # If no arguments provided, run interactive mode
    if [[ $# -eq 0 ]]; then
        # Check if interactive_mode function exists
        if declare -f interactive_mode >/dev/null; then
            interactive_mode
        else
            echo "Error: Interactive mode not available"
            echo "Function file 'interactive_functions.sh' may be missing"
            exit 1
        fi
        return 0
    fi
    
    # Handle command line arguments
    local command=$1
    shift  # Remove first argument
    
    case $command in
        # Single operations
        "create")
            if declare -f add_fresh_vhost >/dev/null; then
                add_fresh_vhost "$@"
            else
                echo "Error: Function 'add_fresh_vhost' not available"
                exit 1
            fi
            ;;
        
        "delete")
            if declare -f delete_fresh_vhost >/dev/null; then
                delete_fresh_vhost "$@"
            else
                echo "Error: Function 'delete_fresh_vhost' not available"
                exit 1
            fi
            ;;
        
        "update")
            if declare -f update_fresh_vhost >/dev/null; then
                update_fresh_vhost "$@"
            else
                echo "Error: Function 'update_fresh_vhost' not available"
                exit 1
            fi
            ;;
        
        "clone")
            if declare -f clone_fresh_vhost >/dev/null; then
                clone_fresh_vhost "$@"
            else
                echo "Error: Function 'clone_fresh_vhost' not available"
                exit 1
            fi
            ;;
        
        "validate")
            if declare -f validate_fresh_vhost >/dev/null; then
                validate_fresh_vhost "$@"
            else
                echo "Error: Function 'validate_fresh_vhost' not available"
                exit 1
            fi
            ;;
        
        "info")
            if declare -f show_vhost_info >/dev/null; then
                show_vhost_info "$@"
            else
                echo "Error: Function 'show_vhost_info' not available"
                exit 1
            fi
            ;;
        
        # Bulk operations
        "bulk")
            if declare -f create_bulk_fresh_vhosts >/dev/null; then
                create_bulk_fresh_vhosts
            else
                echo "Error: Function 'create_bulk_fresh_vhosts' not available"
                exit 1
            fi
            ;;
        
        "bulk-brand")
            if declare -f create_bulk_brand_fresh_vhosts >/dev/null; then
                create_bulk_brand_fresh_vhosts
            else
                echo "Error: Function 'create_bulk_brand_fresh_vhosts' not available"
                exit 1
            fi
            ;;
        
        "bulk-delete")
            if declare -f bulk_delete_fresh_vhosts >/dev/null; then
                bulk_delete_fresh_vhosts
            else
                echo "Error: Function 'bulk_delete_fresh_vhosts' not available"
                exit 1
            fi
            ;;
        
        # List and status
        "list")
            if declare -f list_fresh_vhosts >/dev/null; then
                list_fresh_vhosts
            else
                echo "Error: Function 'list_fresh_vhosts' not available"
                exit 1
            fi
            ;;
        
        "status")
            if declare -f list_vhost_status >/dev/null; then
                list_vhost_status
            else
                echo "Error: Function 'list_vhost_status' not available"
                exit 1
            fi
            ;;
        
        # Enable/disable operations
        "enable")
            if declare -f toggle_vhost >/dev/null; then
                toggle_vhost "$1" "enable"
            else
                echo "Error: Function 'toggle_vhost' not available"
                exit 1
            fi
            ;;
        
        "disable")
            if declare -f toggle_vhost >/dev/null; then
                toggle_vhost "$1" "disable"
            else
                echo "Error: Function 'toggle_vhost' not available"
                exit 1
            fi
            ;;
        
        "bulk-enable")
            if declare -f bulk_toggle_vhosts >/dev/null; then
                bulk_toggle_vhosts "enable"
            else
                echo "Error: Function 'bulk_toggle_vhosts' not available"
                exit 1
            fi
            ;;
        
        "bulk-disable")
            if declare -f bulk_toggle_vhosts >/dev/null; then
                bulk_toggle_vhosts "disable"
            else
                echo "Error: Function 'bulk_toggle_vhosts' not available"
                exit 1
            fi
            ;;
        
        # Backup and restore
        "backup")
            if declare -f bulk_backup_fresh_vhosts >/dev/null; then
                bulk_backup_fresh_vhosts "$1"
            else
                echo "Error: Function 'bulk_backup_fresh_vhosts' not available"
                exit 1
            fi
            ;;
        
        "restore")
            if declare -f restore_fresh_vhosts_from_backup >/dev/null; then
                restore_fresh_vhosts_from_backup "$1"
            else
                echo "Error: Function 'restore_fresh_vhosts_from_backup' not available"
                exit 1
            fi
            ;;
        
        # Nginx operations
        "nginx-test")
            echo "Testing nginx configuration..."
            nginx -t
            ;;
        
        "nginx-reload")
            if declare -f reload_nginx >/dev/null; then
                reload_nginx
            else
                echo "Reloading nginx..."
                systemctl reload nginx
            fi
            ;;
        
        "nginx-status")
            if declare -f check_nginx_status >/dev/null; then
                check_nginx_status
            else
                echo "Checking nginx status..."
                systemctl status nginx
            fi
            ;;
        
        # Help and usage
        "help"|"-h"|"--help")
            show_usage
            ;;
        
        # Unknown command
        *)
            echo "Error: Unknown command '$command'"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    main "$@"
fi