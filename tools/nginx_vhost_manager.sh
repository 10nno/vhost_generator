#!/bin/bash

# Enhanced Nginx VHost Manager Script
# File: nginx_vhost_manager.sh
# Enhanced to work with multiple domains per category database structure

# Get the main project directory (parent of tools directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATABASE_DIR="$MAIN_DIR/database"
DATABASE_FILE="$DATABASE_DIR/domains_db.sh"
VHOST_DIR="$MAIN_DIR/vhost/kawal"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

# Source the database file
if [[ -f "$DATABASE_FILE" ]]; then
    source "$DATABASE_FILE"
else
    echo "Error: Database file not found at: $DATABASE_FILE"
    echo "Please ensure the domain database is properly set up."
    exit 1
fi

# Function to create vhost directory if it doesn't exist
init_vhost_directory() {
    if [[ ! -d "$VHOST_DIR" ]]; then
        mkdir -p "$VHOST_DIR"
        echo "Created vhost directory: $VHOST_DIR"
    fi
}

# Function to generate vhost file content for single domain
generate_vhost_content() {
    local domain=$1
    local proxy_pass=${2:-"http://103.35.205.253:8000"}
    
    cat << EOF
server {
    server_name $domain;

    location / {
        proxy_pass $proxy_pass;  # Send request to Laravel
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    listen 443;
}
EOF
}

# Function to generate vhost file content for multiple domains
generate_multi_domain_vhost_content() {
    local domains=$1
    local proxy_pass=${2:-"http://103.35.205.253:8000"}
    
    # Convert comma-separated domains to space-separated
    local server_names=$(echo "$domains" | tr ',' ' ')
    
    cat << EOF
server {
    server_name $server_names;

    location / {
        proxy_pass $proxy_pass;  # Send request to Laravel
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    listen 443;
}
EOF
}

# Function to create vhost files for a specific brand and category
create_vhost_for_brand_category() {
    local brand=$1
    local category=$2
    local custom_proxy=${3:-""}
    local mode=${4:-"separate"}  # separate or combined
    
    if [[ -z "$brand" || -z "$category" ]]; then
        echo "Usage: create_vhost_for_brand_category <BRAND> <CATEGORY> [CUSTOM_PROXY_URL] [MODE]"
        echo "Categories: main, kawal, fresh"
        echo "Mode: separate (default) - one file per domain, combined - all domains in one file"
        return 1
    fi
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Check if brand exists
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found in database."
        echo "Available brands:"
        get_all_brands
        return 1
    fi
    
    # Get domains for the brand and category
    local domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -ne 0 || -z "$domains" ]]; then
        echo "Error: No $category domains found for brand '$brand'"
        return 1
    fi
    
    # Initialize vhost directory
    init_vhost_directory
    
    local proxy_url=${custom_proxy:-"http://103.35.205.253:8000"}
    local created_files=()
    
    if [[ "$mode" == "combined" ]]; then
        # Create one vhost file with all domains
        local vhost_filename="${brand}_${category}_combined_vhost"
        local vhost_filepath="$VHOST_DIR/$vhost_filename"
        
        # Check if vhost file already exists
        if [[ -f "$vhost_filepath" ]]; then
            echo "VHost file already exists: $vhost_filepath"
            read -p "Do you want to overwrite it? (y/n): " overwrite
            if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
                echo "VHost creation cancelled."
                return 1
            fi
        fi
        
        # Generate and write combined vhost content
        generate_multi_domain_vhost_content "$domains" "$proxy_url" > "$vhost_filepath"
        
        echo "✓ Created combined vhost file: $vhost_filepath"
        echo "✓ Domains: $domains"
        echo "✓ Proxy pass: $proxy_url"
        created_files+=("$vhost_filename")
        
    else
        # Create separate vhost files for each domain
        IFS=',' read -ra domain_array <<< "$domains"
        for domain in "${domain_array[@]}"; do
            local vhost_filename="${domain}_vhost"
            local vhost_filepath="$VHOST_DIR/$vhost_filename"
            
            # Check if vhost file already exists
            if [[ -f "$vhost_filepath" ]]; then
                echo "VHost file already exists: $vhost_filepath"
                read -p "Do you want to overwrite it? (y/n): " overwrite
                if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
                    echo "Skipping $domain"
                    continue
                fi
            fi
            
            # Generate and write vhost content
            generate_vhost_content "$domain" "$proxy_url" > "$vhost_filepath"
            
            echo "✓ Created vhost file: $vhost_filepath"
            echo "✓ Domain: $domain"
            echo "✓ Proxy pass: $proxy_url"
            created_files+=("$vhost_filename")
        done
    fi
    
    # Store created files for potential symlink creation
    echo ""
    echo "Created ${#created_files[@]} vhost file(s)"
    return 0
}

# Function to create vhost files for all categories of a brand
create_vhost_for_brand_all_categories() {
    local brand=$1
    local custom_proxy=${2:-""}
    local mode=${3:-"separate"}
    
    if [[ -z "$brand" ]]; then
        echo "Usage: create_vhost_for_brand_all_categories <BRAND> [CUSTOM_PROXY_URL] [MODE]"
        return 1
    fi
    
    echo "Creating vhost files for all categories of brand: $brand"
    echo "======================================================"
    
    local categories=("main" "kawal" "fresh")
    local total_created=0
    
    for category in "${categories[@]}"; do
        echo ""
        echo "Processing $category domains..."
        echo "------------------------------"
        
        local domains=$(get_brand_domains "$brand" "$category")
        if [[ $? -eq 0 && -n "$domains" ]]; then
            if create_vhost_for_brand_category "$brand" "$category" "$custom_proxy" "$mode"; then
                local domain_count=$(get_domain_count "$brand" "$category")
                ((total_created += domain_count))
            fi
        else
            echo "No $category domains found for brand $brand"
        fi
    done
    
    echo ""
    echo "Summary: Created vhost files for $total_created domains"
}

# Function to create nginx symlink for a specific vhost file
create_nginx_symlink() {
    local vhost_filename=$1
    
    if [[ -z "$vhost_filename" ]]; then
        echo "Usage: create_nginx_symlink <VHOST_FILENAME>"
        return 1
    fi
    
    local vhost_filepath="$VHOST_DIR/$vhost_filename"
    local symlink_path="$NGINX_SITES_ENABLED/$vhost_filename"
    
    # Check if vhost file exists
    if [[ ! -f "$vhost_filepath" ]]; then
        echo "Error: VHost file not found: $vhost_filepath"
        return 1
    fi
    
    # Check if we have permission to write to nginx directory
    if [[ ! -w "$NGINX_SITES_ENABLED" ]]; then
        echo "Error: No write permission to $NGINX_SITES_ENABLED"
        echo "You may need to run this script with sudo or adjust permissions."
        return 1
    fi
    
    # Check if symlink already exists
    if [[ -L "$symlink_path" ]]; then
        echo "Symlink already exists: $symlink_path"
        read -p "Do you want to recreate it? (y/n): " recreate
        if [[ "$recreate" == "y" || "$recreate" == "Y" ]]; then
            rm "$symlink_path"
        else
            echo "Symlink creation cancelled."
            return 1
        fi
    elif [[ -f "$symlink_path" ]]; then
        echo "Error: File exists but is not a symlink: $symlink_path"
        return 1
    fi
    
    # Create symlink
    ln -s "$vhost_filepath" "$symlink_path"
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Created symlink: $symlink_path -> $vhost_filepath"
    else
        echo "✗ Failed to create symlink"
        return 1
    fi
}

# Function to create symlinks for brand's category domains
create_symlinks_for_brand_category() {
    local brand=$1
    local category=$2
    local mode=${3:-"separate"}
    
    if [[ -z "$brand" || -z "$category" ]]; then
        echo "Usage: create_symlinks_for_brand_category <BRAND> <CATEGORY> [MODE]"
        return 1
    fi
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    local domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -ne 0 || -z "$domains" ]]; then
        echo "No $category domains found for brand $brand"
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    if [[ "$mode" == "combined" ]]; then
        # Create symlink for combined vhost file
        local vhost_filename="${brand}_${category}_combined_vhost"
        ((total_count++))
        if create_nginx_symlink "$vhost_filename"; then
            ((success_count++))
        fi
    else
        # Create symlinks for separate vhost files
        IFS=',' read -ra domain_array <<< "$domains"
        for domain in "${domain_array[@]}"; do
            local vhost_filename="${domain}_vhost"
            ((total_count++))
            if create_nginx_symlink "$vhost_filename"; then
                ((success_count++))
            fi
        done
    fi
    
    echo "Created $success_count/$total_count symlinks for $brand $category domains"
}

# Function to remove nginx symlink
remove_nginx_symlink() {
    local vhost_filename=$1
    
    if [[ -z "$vhost_filename" ]]; then
        echo "Usage: remove_nginx_symlink <VHOST_FILENAME>"
        return 1
    fi
    
    local symlink_path="$NGINX_SITES_ENABLED/$vhost_filename"
    
    if [[ -L "$symlink_path" ]]; then
        rm "$symlink_path"
        echo "✓ Removed symlink: $symlink_path"
    elif [[ -f "$symlink_path" ]]; then
        echo "Warning: File exists but is not a symlink: $symlink_path"
        read -p "Do you want to remove it anyway? (y/n): " remove_file
        if [[ "$remove_file" == "y" || "$remove_file" == "Y" ]]; then
            rm "$symlink_path"
            echo "✓ Removed file: $symlink_path"
        fi
    else
        echo "Symlink not found: $symlink_path"
        return 1
    fi
}

# Function to deploy vhost (create + symlink) for brand category
deploy_vhost_for_brand_category() {
    local brand=$1
    local category=$2
    local custom_proxy=${3:-""}
    local mode=${4:-"separate"}
    
    if [[ -z "$brand" || -z "$category" ]]; then
        echo "Usage: deploy_vhost_for_brand_category <BRAND> <CATEGORY> [CUSTOM_PROXY_URL] [MODE]"
        return 1
    fi
    
    echo "Deploying vhost for brand: $brand, category: $category"
    echo "====================================================="
    
    # Create vhost files
    if create_vhost_for_brand_category "$brand" "$category" "$custom_proxy" "$mode"; then
        echo ""
        # Create symlinks
        if create_symlinks_for_brand_category "$brand" "$category" "$mode"; then
            echo ""
            echo "✓ VHost deployment completed successfully!"
            echo "✓ Don't forget to reload nginx: sudo systemctl reload nginx"
        else
            echo "✗ VHost files created but symlink creation had issues"
            return 1
        fi
    else
        echo "✗ VHost deployment failed"
        return 1
    fi
}

# Function to list all vhost files
list_vhost_files() {
    echo "VHost Files in $VHOST_DIR"
    echo "========================="
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "VHost directory doesn't exist: $VHOST_DIR"
        return 1
    fi
    
    local count=0
    for vhost_file in "$VHOST_DIR"/*_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain_name="${filename%_vhost}"
            local symlink_path="$NGINX_SITES_ENABLED/$filename"
            
            printf "%-40s" "$domain_name"
            if [[ -L "$symlink_path" ]]; then
                echo " [ENABLED]"
            else
                echo " [DISABLED]"
            fi
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "No vhost files found."
    else
        echo ""
        echo "Total vhost files: $count"
    fi
}

# Function to show vhost files by brand
list_vhost_files_by_brand() {
    local brand=$1
    
    if [[ -z "$brand" ]]; then
        echo "Usage: list_vhost_files_by_brand <BRAND>"
        return 1
    fi
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found in database."
        return 1
    fi
    
    echo "VHost Files for Brand: $brand"
    echo "============================="
    
    local categories=("main" "kawal" "fresh")
    local total_files=0
    
    for category in "${categories[@]}"; do
        local domains=$(get_brand_domains "$brand" "$category")
        if [[ $? -eq 0 && -n "$domains" ]]; then
            echo ""
            echo "$category domains:"
            echo "$(printf '%.0s-' {1..20})"
            
            IFS=',' read -ra domain_array <<< "$domains"
            for domain in "${domain_array[@]}"; do
                local vhost_filename="${domain}_vhost"
                local vhost_filepath="$VHOST_DIR/$vhost_filename"
                local symlink_path="$NGINX_SITES_ENABLED/$vhost_filename"
                
                printf "  %-35s" "$domain"
                if [[ -f "$vhost_filepath" ]]; then
                    if [[ -L "$symlink_path" ]]; then
                        echo " [FILE EXISTS] [ENABLED]"
                    else
                        echo " [FILE EXISTS] [DISABLED]"
                    fi
                    ((total_files++))
                else
                    echo " [NO FILE]"
                fi
            done
            
            # Check for combined vhost file
            local combined_filename="${brand}_${category}_combined_vhost"
            local combined_filepath="$VHOST_DIR/$combined_filename"
            local combined_symlink="$NGINX_SITES_ENABLED/$combined_filename"
            
            if [[ -f "$combined_filepath" ]]; then
                printf "  %-35s" "COMBINED_${category}"
                if [[ -L "$combined_symlink" ]]; then
                    echo " [COMBINED FILE] [ENABLED]"
                else
                    echo " [COMBINED FILE] [DISABLED]"
                fi
                ((total_files++))
            fi
        fi
    done
    
    echo ""
    echo "Total vhost files for $brand: $total_files"
}

# Function to create vhosts for all brands (kawal domains only)
create_kawal_vhosts_for_all_brands() {
    local custom_proxy=${1:-""}
    local mode=${2:-"separate"}
    
    echo "Creating kawal vhost files for all brands"
    echo "=========================================="
    
    local success_count=0
    local total_brands=0
    local total_domains=0
    
    for brand in $(get_all_brands); do
        ((total_brands++))
        echo ""
        echo "Processing brand: $brand"
        echo "$(printf '%.0s-' {1..30})"
        
        local kawal_domains=$(get_brand_domains "$brand" "kawal")
        if [[ $? -eq 0 && -n "$kawal_domains" ]]; then
            if create_vhost_for_brand_category "$brand" "kawal" "$custom_proxy" "$mode"; then
                ((success_count++))
                local domain_count=$(get_domain_count "$brand" "kawal")
                ((total_domains += domain_count))
            fi
        else
            echo "No kawal domains found for brand $brand"
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "========"
    echo "Total brands: $total_brands"
    echo "Successfully processed: $success_count"
    echo "Total kawal domains: $total_domains"
    echo "Failed: $((total_brands - success_count))"
}

# Function to deploy all kawal domains (create files and symlinks)
deploy_all_kawal_vhosts() {
    local custom_proxy=${1:-""}
    local mode=${2:-"separate"}
    
    echo "Deploying kawal vhost files for all brands"
    echo "==========================================="
    
    local success_count=0
    local total_brands=0
    
    for brand in $(get_all_brands); do
        ((total_brands++))
        echo ""
        echo "Processing brand: $brand"
        echo "$(printf '%.0s-' {1..30})"
        
        if deploy_vhost_for_brand_category "$brand" "kawal" "$custom_proxy" "$mode"; then
            ((success_count++))
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "========"
    echo "Total brands: $total_brands"
    echo "Successfully deployed: $success_count"
    echo "Failed: $((total_brands - success_count))"
    echo ""
    echo "Don't forget to reload nginx: sudo systemctl reload nginx"
}

# Function to check nginx configuration
check_nginx_config() {
    echo "Checking nginx configuration..."
    
    if command -v nginx >/dev/null 2>&1; then
        nginx -t
        if [[ $? -eq 0 ]]; then
            echo "✓ Nginx configuration is valid"
        else
            echo "✗ Nginx configuration has errors"
        fi
    else
        echo "Warning: nginx command not found"
    fi
}

# Function to reload nginx
reload_nginx() {
    echo "Reloading nginx..."
    
    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl reload nginx
        if [[ $? -eq 0 ]]; then
            echo "✓ Nginx reloaded successfully"
        else
            echo "✗ Failed to reload nginx"
        fi
    else
        echo "Warning: systemctl command not found"
        echo "Try manually: sudo service nginx reload"
    fi
}

# Main menu function
show_menu() {
    echo ""
    echo "Enhanced Nginx VHost Manager - Multiple Domains Support"
    echo "======================================================="
    echo "1. Create vhost for brand category"
    echo "2. Create vhost for all brand categories"
    echo "3. Deploy vhost for brand category (create + symlink)"
    echo "4. Create symlink for existing vhost"
    echo "5. Remove symlink"
    echo "6. List all vhost files"
    echo "7. List vhost files by brand"
    echo "8. Create kawal vhosts for all brands"
    echo "9. Deploy all kawal vhosts"
    echo "10. Check nginx configuration"
    echo "11. Reload nginx"
    echo "12. Exit"
    echo ""
}

# Main script execution
main() {
    # Check if arguments were provided
    if [[ $# -gt 0 ]]; then
        case $1 in
            "create")
                if [[ $# -ge 3 ]]; then
                    create_vhost_for_brand_category "$2" "$3" "$4" "$5"
                else
                    echo "Usage: $0 create <BRAND> <CATEGORY> [CUSTOM_PROXY_URL] [MODE]"
                    echo "Categories: main, kawal, fresh"
                    echo "Mode: separate (default), combined"
                fi
                ;;
            "create-all")
                if [[ $# -ge 2 ]]; then
                    create_vhost_for_brand_all_categories "$2" "$3" "$4"
                else
                    echo "Usage: $0 create-all <BRAND> [CUSTOM_PROXY_URL] [MODE]"
                fi
                ;;
            "deploy")
                if [[ $# -ge 3 ]]; then
                    deploy_vhost_for_brand_category "$2" "$3" "$4" "$5"
                else
                    echo "Usage: $0 deploy <BRAND> <CATEGORY> [CUSTOM_PROXY_URL] [MODE]"
                    echo "Categories: main, kawal, fresh"
                fi
                ;;
            "symlink")
                create_nginx_symlink "$2"
                ;;
            "remove")
                remove_nginx_symlink "$2"
                ;;
            "list")
                if [[ -n "$2" ]]; then
                    list_vhost_files_by_brand "$2"
                else
                    list_vhost_files
                fi
                ;;
            "create-kawal-all")
                create_kawal_vhosts_for_all_brands "$2" "$3"
                ;;
            "deploy-kawal-all")
                deploy_all_kawal_vhosts "$2" "$3"
                ;;
            "check")
                check_nginx_config
                ;;
            "reload")
                reload_nginx
                ;;
            *)
                echo "Usage: $0 [command] [parameters]"
                echo ""
                echo "Commands:"
                echo "  create <BRAND> <CATEGORY> [PROXY] [MODE]    - Create vhost for brand category"
                echo "  create-all <BRAND> [PROXY] [MODE]           - Create vhost for all categories"
                echo "  deploy <BRAND> <CATEGORY> [PROXY] [MODE]    - Deploy vhost (create + symlink)"
                echo "  symlink <VHOST_FILENAME>                    - Create symlink"
                echo "  remove <VHOST_FILENAME>                     - Remove symlink"
                echo "  list [BRAND]                                - List vhost files"
                echo "  create-kawal-all [PROXY] [MODE]             - Create kawal vhosts for all brands"
                echo "  deploy-kawal-all [PROXY] [MODE]             - Deploy all kawal vhosts"
                echo "  check                                       - Check nginx config"
                echo "  reload                                      - Reload nginx"
                echo ""
                echo "Examples:"
                echo "  $0 create MILDCASINO kawal"
                echo "  $0 create MILDCASINO kawal http://custom:8080 combined"
                echo "  $0 deploy AREASLOTS kawal"
                echo "  $0 list MILDCASINO"
                echo "  $0 deploy-kawal-all"
                ;;
        esac
    else
        # Interactive mode
        while true; do
            show_menu
            read -p "Choose an option (1-12): " choice
            
            case $choice in
                1)
                    read -p "Enter brand name: " brand_name
                    read -p "Enter category (main/kawal/fresh): " category
                    read -p "Enter custom proxy URL (or press Enter for default): " proxy_url
                    read -p "Enter mode (separate/combined) [separate]: " mode
                    mode=${mode:-"separate"}
                    create_vhost_for_brand_category "$brand_name" "$category" "$proxy_url" "$mode"
                    ;;
                2)
                    read -p "Enter brand name: " brand_name
                    read -p "Enter custom proxy URL (or press Enter for default): " proxy_url
                    read -p "Enter mode (separate/combined) [separate]: " mode
                    mode=${mode:-"separate"}
                    create_vhost_for_brand_all_categories "$brand_name" "$proxy_url" "$mode"
                    ;;
                3)
                    read -p "Enter brand name: " brand_name
                    read -p "Enter category (main/kawal/fresh): " category
                    read -p "Enter custom proxy URL (or press Enter for default): " proxy_url
                    read -p "Enter mode (separate/combined) [separate]: " mode
                    mode=${mode:-"separate"}
                    deploy_vhost_for_brand_category "$brand_name" "$category" "$proxy_url" "$mode"
                    ;;
                4)
                    read -p "Enter vhost filename: " vhost_filename
                    create_nginx_symlink "$vhost_filename"
                    ;;
                5)
                    read -p "Enter vhost filename: " vhost_filename
                    remove_nginx_symlink "$vhost_filename"
                    ;;
                6) list_vhost_files ;;
                7)
                    read -p "Enter brand name: " brand_name
                    list_vhost_files_by_brand "$brand_name"
                    ;;
                8)
                    read -p "Enter custom proxy URL for all (or press Enter for default): " proxy_url
                    read -p "Enter mode (separate/combined) [separate]: " mode
                    mode=${mode:-"separate"}
                    create_kawal_vhosts_for_all_brands "$proxy_url" "$mode"
                    ;;
                9)
                    read -p "Enter custom proxy URL for all (or press Enter for default): " proxy_url
                    read -p "Enter mode (separate/combined) [separate]: " mode
                    mode=${mode:-"separate"}
                    deploy_all_kawal_vhosts "$proxy_url" "$mode"
                    ;;
                10) check_nginx_config ;;
                11) reload_nginx ;;
                12) echo "Goodbye!"; exit 0 ;;
                *) echo "Invalid option. Please choose 1-12." ;;
            esac
            
            read -p "Press Enter to continue..."
        done
    fi
}

# Run main function with all arguments
main "$@"