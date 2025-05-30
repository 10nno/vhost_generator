#!/bin/bash

# Enhanced Domain Manager Script
# File: domain_manager.sh
# Enhanced to support multiple domains per category

# Get the main project directory (parent of tools directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATABASE_DIR="$MAIN_DIR/database"
DATABASE_FILE="$DATABASE_DIR/domains_db.sh"

# Source the database file
if [[ -f "$DATABASE_FILE" ]]; then
    source "$DATABASE_FILE"
else
    echo "Error: Database file not found at: $DATABASE_FILE"
    echo "Expected directory structure:"
    echo "main_folder/"
    echo "├── database/"
    echo "│   └── domains_db.sh"
    echo "└── tools/"
    echo "    └── domain_manager.sh"
    echo ""
    echo "Current script location: $SCRIPT_DIR"
    echo "Looking for database at: $DATABASE_FILE"
    exit 1
fi

# Function to list all available brands
list_all_brands() {
    local brand_count=$(get_brand_count)
    echo "Available brands ($brand_count total):"
    echo "======================================"
    
    local counter=1
    for brand in $(get_all_brands); do
        local main_count=$(get_domain_count "$brand" "main")
        local kawal_count=$(get_domain_count "$brand" "kawal")
        local fresh_count=$(get_domain_count "$brand" "fresh")
        local total_count=$((main_count + kawal_count + fresh_count))
        
        echo "$counter. $brand (Main: $main_count, Kawal: $kawal_count, Fresh: $fresh_count, Total: $total_count)"
        ((counter++))
    done
}

# Function to list domains for a specific brand
list_domains_for_brand() {
    local brand=$1
    
    if [[ -z "$brand" ]]; then
        echo "Usage: list_domains_for_brand <BRAND_NAME>"
        return 1
    fi
    
    # Convert to uppercase for consistency
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found in database."
        echo ""
        list_all_brands
        return 1
    fi
    
    echo "Domains for brand: $brand"
    echo "=========================="
    
    # Display main domains
    local main_domains=$(get_brand_domains "$brand" "main")
    echo "Main Domains ($(get_domain_count "$brand" "main")):"
    if [[ -n "$main_domains" ]]; then
        IFS=',' read -ra domain_array <<< "$main_domains"
        for i in "${!domain_array[@]}"; do
            echo "  [$i] ${domain_array[$i]}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    # Display kawal domains
    local kawal_domains=$(get_brand_domains "$brand" "kawal")
    echo "Kawal Domains ($(get_domain_count "$brand" "kawal")):"
    if [[ -n "$kawal_domains" ]]; then
        IFS=',' read -ra domain_array <<< "$kawal_domains"
        for i in "${!domain_array[@]}"; do
            echo "  [$i] ${domain_array[$i]}"
        done
    else
        echo "  (none)"
    fi
    echo ""
    
    # Display fresh domains
    local fresh_domains=$(get_brand_domains "$brand" "fresh")
    echo "Fresh Domains ($(get_domain_count "$brand" "fresh")):"
    if [[ -n "$fresh_domains" ]]; then
        IFS=',' read -ra domain_array <<< "$fresh_domains"
        for i in "${!domain_array[@]}"; do
            echo "  [$i] ${domain_array[$i]}"
        done
    else
        echo "  (none)"
    fi
}

# Function to get specific domain(s) from a category
get_domains_from_category() {
    local brand=$1
    local category=$2
    local index=$3
    
    if [[ -z "$brand" || -z "$category" ]]; then
        echo "Usage: get_domains_from_category <BRAND> <CATEGORY> [INDEX]"
        echo "Categories: main, kawal, fresh"
        echo "Index: optional, returns specific domain by index (0-based)"
        return 1
    fi
    
    # Convert brand to uppercase for consistency
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if [[ -n "$index" ]]; then
        # Get specific domain by index
        local result=$(get_domain_by_index "$brand" "$category" "$index")
        if [[ $? -eq 0 ]]; then
            echo "$result"
        else
            echo "Error: $result"
            return 1
        fi
    else
        # Get all domains in category
        local domains=$(get_brand_domains "$brand" "$category")
        if [[ $? -eq 0 && -n "$domains" ]]; then
            echo "$domains"
        else
            echo "No domains found for brand '$brand' in category '$category'"
            return 1
        fi
    fi
}

# Function to add new brand with multiple domains
add_new_brand() {
    local brand=$1
    shift
    local main_domains=""
    local kawal_domains=""
    local fresh_domains=""
    
    if [[ -z "$brand" ]]; then
        echo "Usage: add_new_brand <BRAND> --main domain1,domain2 --kawal domain1,domain2 --fresh domain1,domain2"
        echo "Example: add_new_brand NEWBRAND --main new.com,new.org --kawal newkawal.com --fresh newfresh.com,newfresh.net"
        return 1
    fi
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --main)
                main_domains="$2"
                shift 2
                ;;
            --kawal)
                kawal_domains="$2"
                shift 2
                ;;
            --fresh)
                fresh_domains="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Check if brand already exists
    if brand_exists "$brand"; then
        echo "Brand '$brand' already exists in database!"
        echo "Current domains:"
        list_domains_for_brand "$brand"
        return 1
    fi
    
    # Add new brand to database
    add_brand_to_db "$brand" "$main_domains" "$kawal_domains" "$fresh_domains"
    
    echo "Successfully added new brand: $brand"
    echo "Main domains   : $main_domains"
    echo "Kawal domains  : $kawal_domains"
    echo "Fresh domains  : $fresh_domains"
    echo ""
    echo "Total brands: $(get_brand_count)"
}

# Interactive function to add new brand
interactive_add_brand() {
    echo "Add New Brand to Database"
    echo "========================="
    
    read -p "Enter brand name: " brand
    echo ""
    echo "Enter domains for each category (separate multiple domains with commas):"
    read -p "Main domains: " main_domains
    read -p "Kawal domains: " kawal_domains
    read -p "Fresh domains: " fresh_domains
    
    echo ""
    echo "Review your input:"
    echo "Brand         : $brand"
    echo "Main domains  : $main_domains"
    echo "Kawal domains : $kawal_domains"
    echo "Fresh domains : $fresh_domains"
    echo ""
    
    read -p "Is this correct? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        add_brand_to_db "$brand" "$main_domains" "$kawal_domains" "$fresh_domains"
        echo "Brand added successfully!"
        echo "Total brands: $(get_brand_count)"
    else
        echo "Addition cancelled."
    fi
}

# Function to add domain to existing brand category
add_domain_to_brand() {
    local brand=$1
    local category=$2
    local domain=$3
    
    if [[ -z "$brand" || -z "$category" || -z "$domain" ]]; then
        echo "Usage: add_domain_to_brand <BRAND> <CATEGORY> <DOMAIN>"
        echo "Categories: main, kawal, fresh"
        return 1
    fi
    
    add_domain_to_category "$brand" "$category" "$domain"
}

# Function to remove domain from brand category
remove_domain_from_brand() {
    local brand=$1
    local category=$2
    local domain=$3
    
    if [[ -z "$brand" || -z "$category" || -z "$domain" ]]; then
        echo "Usage: remove_domain_from_brand <BRAND> <CATEGORY> <DOMAIN>"
        echo "Categories: main, kawal, fresh"
        return 1
    fi
    
    remove_domain_from_category "$brand" "$category" "$domain"
}

# Function to search domains across all brands
search_domain() {
    local search_term=$1
    
    if [[ -z "$search_term" ]]; then
        echo "Usage: search_domain <search_term>"
        return 1
    fi
    
    echo "Search results for: $search_term"
    echo "================================="
    
    local results=$(search_domains_global "$search_term")
    if [[ $? -eq 0 ]]; then
        echo "$results" | while IFS=':' read -r brand category domain; do
            echo "Brand: $brand | Category: $category | Domain: $domain"
        done
    else
        echo "No results found for '$search_term'"
    fi
}

# Function to display all domains in a formatted table
show_all_domains() {
    local brand_count=$(get_brand_count)
    echo "All Domain Data ($brand_count brands)"
    echo "===================================="
    
    for brand in $(get_all_brands); do
        echo ""
        echo "Brand: $brand"
        echo "$(printf '%.0s-' {1..50})"
        
        # Main domains
        local main_domains=$(get_brand_domains "$brand" "main")
        echo "Main ($(get_domain_count "$brand" "main")):"
        if [[ -n "$main_domains" ]]; then
            IFS=',' read -ra domain_array <<< "$main_domains"
            for domain in "${domain_array[@]}"; do
                echo "  • $domain"
            done
        else
            echo "  (none)"
        fi
        
        # Kawal domains
        local kawal_domains=$(get_brand_domains "$brand" "kawal")
        echo "Kawal ($(get_domain_count "$brand" "kawal")):"
        if [[ -n "$kawal_domains" ]]; then
            IFS=',' read -ra domain_array <<< "$kawal_domains"
            for domain in "${domain_array[@]}"; do
                echo "  • $domain"
            done
        else
            echo "  (none)"
        fi
        
        # Fresh domains
        local fresh_domains=$(get_brand_domains "$brand" "fresh")
        echo "Fresh ($(get_domain_count "$brand" "fresh")):"
        if [[ -n "$fresh_domains" ]]; then
            IFS=',' read -ra domain_array <<< "$fresh_domains"
            for domain in "${domain_array[@]}"; do
                echo "  • $domain"
            done
        else
            echo "  (none)"
        fi
    done
}

# Function to backup database
backup_database() {
    local backup_dir="$MAIN_DIR/backups"
    local backup_file="$backup_dir/domains_backup_$(date +%Y%m%d_%H%M%S).txt"
    
    # Create backup directory if it doesn't exist
    mkdir -p "$backup_dir"
    
    export_database > "$backup_file"
    echo "Database backed up to: $backup_file"
    echo "Total brands exported: $(get_brand_count)"
}

# Function to restore database from backup
restore_database() {
    local backup_file=$1
    
    if [[ -z "$backup_file" ]]; then
        echo "Usage: restore_database <backup_file>"
        return 1
    fi
    
    if [[ ! -f "$backup_file" ]]; then
        echo "Backup file not found: $backup_file"
        return 1
    fi
    
    echo "Current database has $(get_brand_count) brands."
    read -p "Do you want to restore from backup? This will replace current data. (y/n): " confirm
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        # Clear current database
        for brand in $(get_all_brands); do
            delete_brand_from_db "$brand"
        done
        
        # Import from backup
        import_database "$backup_file"
        echo "Database restored from: $backup_file"
        echo "Total brands: $(get_brand_count)"
    else
        echo "Restore cancelled."
    fi
}

# Function to delete a brand
delete_brand() {
    local brand=$1
    
    if [[ -z "$brand" ]]; then
        echo "Usage: delete_brand <BRAND>"
        return 1
    fi
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found in database."
        return 1
    fi
    
    echo "Current domains for $brand:"
    list_domains_for_brand "$brand"
    echo ""
    
    read -p "Are you sure you want to delete brand '$brand'? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        delete_brand_from_db "$brand"
        echo "Brand '$brand' has been deleted."
        echo "Remaining brands: $(get_brand_count)"
    else
        echo "Deletion cancelled."
    fi
}

# Main menu function
show_menu() {
    echo ""
    echo "Enhanced Domain Database Manager - Multiple Domains Support"
    echo "=========================================================="
    echo "1. List all brands"
    echo "2. Show domains for specific brand"
    echo "3. Get domains from category"
    echo "4. Add new brand (interactive)"
    echo "5. Add domain to existing brand"
    echo "6. Remove domain from brand"
    echo "7. Delete entire brand"
    echo "8. Search domains"
    echo "9. Show all domains"
    echo "10. Backup database"
    echo "11. Restore database"
    echo "12. Exit"
    echo ""
}

# Main script execution
main() {
    # Check if arguments were provided
    if [[ $# -gt 0 ]]; then
        case $1 in
            "list")
                if [[ -n "$2" ]]; then
                    list_domains_for_brand "$2"
                else
                    list_all_brands
                fi
                ;;
            "get")
                if [[ $# -eq 3 ]]; then
                    get_domains_from_category "$2" "$3"
                elif [[ $# -eq 4 ]]; then
                    get_domains_from_category "$2" "$3" "$4"
                else
                    echo "Usage: $0 get <BRAND> <CATEGORY> [INDEX]"
                    echo "Categories: main, kawal, fresh"
                    echo "Index: optional, returns specific domain by index (0-based)"
                fi
                ;;
            "add")
                shift
                add_new_brand "$@"
                ;;
            "add-domain")
                if [[ $# -eq 4 ]]; then
                    add_domain_to_brand "$2" "$3" "$4"
                else
                    echo "Usage: $0 add-domain <BRAND> <CATEGORY> <DOMAIN>"
                    echo "Categories: main, kawal, fresh"
                fi
                ;;
            "remove-domain")
                if [[ $# -eq 4 ]]; then
                    remove_domain_from_brand "$2" "$3" "$4"
                else
                    echo "Usage: $0 remove-domain <BRAND> <CATEGORY> <DOMAIN>"
                    echo "Categories: main, kawal, fresh"
                fi
                ;;
            "delete")
                delete_brand "$2"
                ;;
            "search")
                search_domain "$2"
                ;;
            "show")
                show_all_domains
                ;;
            "backup")
                backup_database
                ;;
            "restore")
                restore_database "$2"
                ;;
            *)
                echo "Usage: $0 [command] [parameters]"
                echo ""
                echo "Commands:"
                echo "  list [BRAND]                         - List all brands or specific brand domains"
                echo "  get <BRAND> <CATEGORY> [INDEX]      - Get domains from category (optionally by index)"
                echo "  add <BRAND> --main <domains> --kawal <domains> --fresh <domains>"
                echo "  add-domain <BRAND> <CATEGORY> <DOMAIN> - Add single domain to existing brand"
                echo "  remove-domain <BRAND> <CATEGORY> <DOMAIN> - Remove domain from brand"
                echo "  delete <BRAND>                       - Delete entire brand"
                echo "  search <TERM>                        - Search across all domains"
                echo "  show                                 - Show all domains"
                echo "  backup                               - Backup database"
                echo "  restore <FILE>                       - Restore from backup"
                echo ""
                echo "Examples:"
                echo "  $0 list MILDCASINO"
                echo "  $0 get MILDCASINO kawal"
                echo "  $0 get MILDCASINO kawal 1"
                echo "  $0 add NEWBRAND --main new.com,new.org --kawal newkawal.com --fresh newfresh.com"
                echo "  $0 add-domain MILDCASINO kawal newkawal2.com"
                echo "  $0 remove-domain MILDCASINO kawal oldkawal.com"
                echo "  $0 search casino"
                ;;
        esac
    else
        # Interactive mode
        while true; do
            show_menu
            read -p "Choose an option (1-12): " choice
            
            case $choice in
                1) list_all_brands ;;
                2) 
                    read -p "Enter brand name: " brand_name
                    list_domains_for_brand "$brand_name"
                    ;;
                3)
                    read -p "Enter brand name: " brand_name
                    read -p "Enter category (main/kawal/fresh): " category
                    read -p "Enter index (optional, press Enter for all): " index
                    if [[ -z "$index" ]]; then
                        get_domains_from_category "$brand_name" "$category"
                    else
                        get_domains_from_category "$brand_name" "$category" "$index"
                    fi
                    ;;
                4) interactive_add_brand ;;
                5)
                    read -p "Enter brand name: " brand_name
                    read -p "Enter category (main/kawal/fresh): " category
                    read -p "Enter domain to add: " domain
                    add_domain_to_brand "$brand_name" "$category" "$domain"
                    ;;
                6)
                    read -p "Enter brand name: " brand_name
                    echo "Current domains for $brand_name:"
                    list_domains_for_brand "$brand_name"
                    echo ""
                    read -p "Enter category (main/kawal/fresh): " category
                    read -p "Enter domain to remove: " domain
                    remove_domain_from_brand "$brand_name" "$category" "$domain"
                    ;;
                7)
                    read -p "Enter brand name to delete: " brand_name
                    delete_brand "$brand_name"
                    ;;
                8) 
                    read -p "Enter search term: " search_term
                    search_domain "$search_term"
                    ;;
                9) show_all_domains ;;
                10) backup_database ;;
                11)
                    read -p "Enter backup file path: " backup_file
                    restore_database "$backup_file"
                    ;;
                12) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid option. Please choose 1-12." ;;
            esac
            
            read -p "Press Enter to continue..."
        done
    fi
}

# Run main function with all arguments
main "$@"