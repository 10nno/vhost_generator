#!/bin/bash

# Add Fresh VHost Script
# File: add_fresh_vhost.sh
# Creates nginx vhost files for fresh domains using template

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

# Function to create directories
init_directories() {
    [[ ! -d "$VHOST_DIR" ]] && mkdir -p "$VHOST_DIR"
    [[ ! -d "$TEMPLATE_DIR" ]] && mkdir -p "$TEMPLATE_DIR"
}

# Function to create template if it doesn't exist
create_template() {
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        cat << 'EOF' > "$TEMPLATE_FILE"
server {
listen 80;
    server_name  *.{{FRESH_DOMAIN}};
return 302 https://$host$request_uri;
}

server {
listen 443 ssl;
 ssl_certificate /etc/letsencrypt/live/{{FRESH_DOMAIN}}/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/{{FRESH_DOMAIN}}/privkey.pem; # managed by Certbot

    server_name  *.{{FRESH_DOMAIN}};

        location / {
            proxy_ssl_server_name on;
            proxy_pass http://{{MAIN_DOMAIN}}/;
            proxy_set_header Accept-Encoding "";
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Host $host;

            proxy_set_header Cookie $http_cookie;

        # Enable sub_filter module
        sub_filter_once off;  # Replace all occurrences, not just the first one
        sub_filter 'http://{{MAIN_DOMAIN}}' $host;
        sub_filter 'action="http://{{MAIN_DOMAIN}}/register"' 'action="https://$host/register"';
        sub_filter_types text/html text/javascript application/javascript;

        proxy_redirect http://{{MAIN_DOMAIN}}/ /;
        proxy_redirect http://{{MAIN_DOMAIN}}/ /;

        sub_filter 'http://{{MAIN_DOMAIN}}' '$scheme://$host';
        sub_filter 'https://{{MAIN_DOMAIN}}' '$scheme://$host';

    }

    error_log on;
    error_log /var/log/nginx/error.log;

                gzip on;
                gzip_disable "msie6";
                gzip_vary on;
                gzip_comp_level 6;
                gzip_min_length 1100;
                gzip_buffers 16 8k;
                gzip_proxied any;
                gzip_types
                text/plain
                text/css
                text/js
                text/xml
                text/javascript
                application/javascript
                application/x-javascript
                application/json
                application/xml
                application/rss+xml
                image/svg+xml;

}
EOF
    fi
}

# Function to get main domain for a brand
get_main_domain() {
    local brand=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    local main_domains=$(get_brand_domains "$brand" "main")
    if [[ $? -eq 0 && -n "$main_domains" ]]; then
        IFS=',' read -ra domain_array <<< "$main_domains"
        echo "${domain_array[0]}"
    fi
}

# Function to run SSL certificate generation
generate_ssl_certificate() {
    local fresh_domain=$1
    
    echo ""
    echo "Generating SSL Certificate..."
    echo "============================"
    echo "Domain: $fresh_domain"
    echo "Wildcard: *.$fresh_domain"
    echo ""
    
    # Check if certbotcf command exists
    if ! command -v certbotcf &> /dev/null; then
        echo "Warning: 'certbotcf' command not found"
        echo "Please install certbot-cloudflare or run manually:"
        echo "certbotcf certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d \"$fresh_domain\" -d \"*.$fresh_domain\""
        return 1
    fi
    
    # Check if cloudflare credentials file exists
    if [[ ! -f "/etc/letsencrypt/cloudflare.ini" ]]; then
        echo "Warning: Cloudflare credentials file not found at /etc/letsencrypt/cloudflare.ini"
        echo "Please create the file or run manually:"
        echo "certbotcf certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d \"$fresh_domain\" -d \"*.$fresh_domain\""
        return 1
    fi
    
    # Run the SSL certificate generation
    echo "Running: certbotcf certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d \"$fresh_domain\" -d \"*.$fresh_domain\""
    echo ""
    
    certbotcf certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d "$fresh_domain" -d "*.$fresh_domain"
    
    local ssl_result=$?
    
    if [[ $ssl_result -eq 0 ]]; then
        echo ""
        echo "✓ SSL certificate generated successfully!"
        return 0
    else
        echo ""
        echo "✗ SSL certificate generation failed!"
        echo "You may need to run it manually with proper permissions (sudo)"
        return 1
    fi
}

# Function to create nginx symlink
create_nginx_symlink() {
    local fresh_domain=$1
    local vhost_file=$2
    
    local symlink_path="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    echo ""
    echo "Creating Nginx Symlink..."
    echo "========================"
    
    # Check if nginx sites-enabled directory exists
    if [[ ! -d "/etc/nginx/sites-enabled" ]]; then
        echo "Warning: /etc/nginx/sites-enabled directory not found"
        echo "Please create symlink manually:"
        echo "ln -s $vhost_file /etc/nginx/sites-enabled/"
        return 1
    fi
    
    # Check if symlink already exists
    if [[ -L "$symlink_path" ]]; then
        echo "Symlink already exists: $symlink_path"
        read -p "Recreate symlink? (y/n): " recreate
        if [[ "$recreate" == "y" || "$recreate" == "Y" ]]; then
            rm "$symlink_path"
        else
            echo "Skipping symlink creation"
            return 0
        fi
    fi
    
    # Create symlink
    ln -s "$vhost_file" "$symlink_path"
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Created symlink: $symlink_path"
        return 0
    else
        echo "✗ Failed to create symlink (may need sudo)"
        echo "Run manually: sudo ln -s $vhost_file /etc/nginx/sites-enabled/"
        return 1
    fi
}

# Function to test and reload nginx
reload_nginx() {
    echo ""
    echo "Testing and Reloading Nginx..."
    echo "============================="
    
    # Test nginx configuration
    echo "Testing nginx configuration..."
    nginx -t
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Nginx configuration is valid"
        
        # Reload nginx
        echo "Reloading nginx..."
        systemctl reload nginx
        
        if [[ $? -eq 0 ]]; then
            echo "✓ Nginx reloaded successfully!"
            return 0
        else
            echo "✗ Failed to reload nginx (may need sudo)"
            echo "Run manually: sudo systemctl reload nginx"
            return 1
        fi
    else
        echo "✗ Nginx configuration has errors!"
        echo "Please fix the configuration before reloading"
        return 1
    fi
}

# Function to create single vhost file (without SSL/symlink prompts)
create_single_vhost_file() {
    local brand=$1
    local fresh_domain=$2
    local main_domain=$3
    local overwrite=${4:-"ask"}  # ask, yes, no
    
    # Create vhost file
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    # Check if file exists
    if [[ -f "$vhost_file" ]]; then
        if [[ "$overwrite" == "ask" ]]; then
            read -p "File exists: $fresh_domain. Overwrite? (y/n): " confirm
            [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 1
        elif [[ "$overwrite" == "no" ]]; then
            echo "⚠ Skipped (exists): $fresh_domain"
            return 1
        fi
    fi
    
    # Generate vhost content
    sed -e "s/{{FRESH_DOMAIN}}/$fresh_domain/g" \
        -e "s/{{MAIN_DOMAIN}}/$main_domain/g" \
        "$TEMPLATE_FILE" > "$vhost_file"
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Created: $fresh_domain"
        return 0
    else
        echo "✗ Failed: $fresh_domain"
        return 1
    fi
}

# Function to bulk create fresh vhosts for all brands
create_bulk_fresh_vhosts() {
    echo "Bulk Create Fresh VHosts"
    echo "========================"
    echo ""
    
    # Initialize
    init_directories
    create_template
    
    # Get all brands
    local brands=($(get_all_brands))
    if [[ ${#brands[@]} -eq 0 ]]; then
        echo "No brands found in database"
        return 1
    fi
    
    # Show summary
    local total_fresh=0
    echo "Available brands and fresh domains:"
    echo "==================================="
    for brand in "${brands[@]}"; do
        local fresh_count=$(get_domain_count "$brand" "fresh")
        echo "$brand: $fresh_count fresh domains"
        ((total_fresh += fresh_count))
    done
    echo ""
    echo "Total fresh domains: $total_fresh"
    echo ""
    
    if [[ $total_fresh -eq 0 ]]; then
        echo "No fresh domains found in any brand"
        return 1
    fi
    
    # Ask for confirmation
    read -p "Create vhost files for all $total_fresh fresh domains? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Bulk creation cancelled"
        return 0
    fi
    
    # Ask about overwrite policy
    echo ""
    echo "Overwrite policy for existing files:"
    echo "1. Ask for each file (default)"
    echo "2. Overwrite all existing files"
    echo "3. Skip existing files"
    echo ""
    read -p "Choose option (1-3): " overwrite_choice
    
    local overwrite_policy="ask"
    case $overwrite_choice in
        2) overwrite_policy="yes" ;;
        3) overwrite_policy="no" ;;
        *) overwrite_policy="ask" ;;
    esac
    
    echo ""
    echo "Starting bulk creation..."
    echo "========================"
    
    local created_count=0
    local skipped_count=0
    local failed_count=0
    
    # Process each brand
    for brand in "${brands[@]}"; do
        echo ""
        echo "Processing brand: $brand"
        echo "------------------------"
        
        # Get fresh domains for this brand
        local fresh_domains=$(get_brand_domains "$brand" "fresh")
        if [[ $? -ne 0 || -z "$fresh_domains" ]]; then
            echo "No fresh domains found for $brand"
            continue
        fi
        
        # Get main domain for this brand
        local main_domain=$(get_main_domain "$brand")
        if [[ -z "$main_domain" ]]; then
            echo "⚠ No main domain found for $brand - skipping all fresh domains"
            continue
        fi
        
        echo "Main domain: $main_domain"
        
        # Process each fresh domain
        IFS=',' read -ra domain_array <<< "$fresh_domains"
        for fresh_domain in "${domain_array[@]}"; do
            # Trim whitespace
            fresh_domain=$(echo "$fresh_domain" | xargs)
            
            if create_single_vhost_file "$brand" "$fresh_domain" "$main_domain" "$overwrite_policy"; then
                ((created_count++))
            else
                if [[ -f "$VHOST_DIR/${fresh_domain}_fresh_vhost" ]]; then
                    ((skipped_count++))
                else
                    ((failed_count++))
                fi
            fi
        done
    done
    
    # Show summary
    echo ""
    echo "Bulk Creation Summary"
    echo "===================="
    echo "✓ Created: $created_count files"
    echo "⚠ Skipped: $skipped_count files"
    echo "✗ Failed: $failed_count files"
    echo "Total processed: $((created_count + skipped_count + failed_count)) files"
    
    if [[ $created_count -gt 0 ]]; then
        echo ""
        echo "Next steps:"
        echo "1. Generate SSL certificates for each domain"
        echo "2. Create nginx symlinks"
        echo "3. Test and reload nginx"
        echo ""
        echo "You can use the individual create mode to handle SSL and symlinks"
        echo "or create them manually for each domain."
    fi
}

# Function to bulk create for specific brand
create_bulk_brand_fresh_vhosts() {
    echo "Bulk Create Fresh VHosts for Specific Brand"
    echo "==========================================="
    echo ""
    
    # Initialize
    init_directories
    create_template
    
    # Get all brands
    local brands=($(get_all_brands))
    if [[ ${#brands[@]} -eq 0 ]]; then
        echo "No brands found in database"
        return 1
    fi
    
    # Show brands
    echo "Available brands:"
    echo "================="
    for i in "${!brands[@]}"; do
        local brand="${brands[$i]}"
        local fresh_count=$(get_domain_count "$brand" "fresh")
        echo "$((i+1)). $brand ($fresh_count fresh domains)"
    done
    echo ""
    
    # Select brand
    read -p "Choose brand (1-${#brands[@]}): " brand_choice
    if [[ ! "$brand_choice" =~ ^[0-9]+$ ]] || [[ $brand_choice -lt 1 ]] || [[ $brand_choice -gt ${#brands[@]} ]]; then
        echo "Invalid brand selection"
        return 1
    fi
    
    local selected_brand="${brands[$((brand_choice-1))]}"
    
    # Get fresh domains for selected brand
    local fresh_domains=$(get_brand_domains "$selected_brand" "fresh")
    if [[ $? -ne 0 || -z "$fresh_domains" ]]; then
        echo "No fresh domains found for brand $selected_brand"
        return 1
    fi
    
    # Get main domain
    local main_domain=$(get_main_domain "$selected_brand")
    if [[ -z "$main_domain" ]]; then
        echo "Error: No main domain found for brand '$selected_brand'"
        return 1
    fi
    
    # Show summary
    IFS=',' read -ra domain_array <<< "$fresh_domains"
    echo ""
    echo "Brand: $selected_brand"
    echo "Main domain: $main_domain"
    echo "Fresh domains to create: ${#domain_array[@]}"
    echo ""
    echo "Fresh domains:"
    for domain in "${domain_array[@]}"; do
        echo "  • $(echo "$domain" | xargs)"
    done
    echo ""
    
    # Ask for confirmation
    read -p "Create vhost files for all ${#domain_array[@]} fresh domains? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Bulk creation cancelled"
        return 0
    fi
    
    # Ask about overwrite policy
    echo ""
    echo "Overwrite policy for existing files:"
    echo "1. Ask for each file (default)"
    echo "2. Overwrite all existing files"
    echo "3. Skip existing files"
    echo ""
    read -p "Choose option (1-3): " overwrite_choice
    
    local overwrite_policy="ask"
    case $overwrite_choice in
        2) overwrite_policy="yes" ;;
        3) overwrite_policy="no" ;;
        *) overwrite_policy="ask" ;;
    esac
    
    echo ""
    echo "Creating vhost files..."
    echo "======================"
    
    local created_count=0
    local skipped_count=0
    local failed_count=0
    
    # Process each fresh domain
    for fresh_domain in "${domain_array[@]}"; do
        # Trim whitespace
        fresh_domain=$(echo "$fresh_domain" | xargs)
        
        if create_single_vhost_file "$selected_brand" "$fresh_domain" "$main_domain" "$overwrite_policy"; then
            ((created_count++))
        else
            if [[ -f "$VHOST_DIR/${fresh_domain}_fresh_vhost" ]]; then
                ((skipped_count++))
            else
                ((failed_count++))
            fi
        fi
    done
    
    # Show summary
    echo ""
    echo "Brand Bulk Creation Summary"
    echo "=========================="
    echo "Brand: $selected_brand"
    echo "✓ Created: $created_count files"
    echo "⚠ Skipped: $skipped_count files"
    echo "✗ Failed: $failed_count files"
    echo "Total processed: $((created_count + skipped_count + failed_count)) files"
    
    if [[ $created_count -gt 0 ]]; then
        echo ""
        read -p "Generate SSL certificates and create symlinks? (y/n): " ssl_confirm
        if [[ "$ssl_confirm" == "y" || "$ssl_confirm" == "Y" ]]; then
            echo ""
            echo "Processing SSL and symlinks..."
            echo "============================="
            
            for fresh_domain in "${domain_array[@]}"; do
                fresh_domain=$(echo "$fresh_domain" | xargs)
                local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
                
                if [[ -f "$vhost_file" ]]; then
                    echo ""
                    echo "Processing: $fresh_domain"
                    echo "------------------------"
                    
                    if generate_ssl_certificate "$fresh_domain"; then
                        create_nginx_symlink "$fresh_domain" "$vhost_file"
                    fi
                fi
            done
            
            echo ""
            read -p "Test and reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                reload_nginx
            fi
        fi
    fi
}

# Main function to add fresh vhost
add_fresh_vhost() {
    local brand=$1
    local fresh_domain=$2
    local main_domain=$3
    local auto_ssl=${4:-"ask"}  # ask, yes, no
    
    if [[ -z "$brand" || -z "$fresh_domain" ]]; then
        echo "Usage: $0 <BRAND> <FRESH_DOMAIN> [MAIN_DOMAIN] [AUTO_SSL]"
        echo "Example: $0 MILDCASINO mildcasino-new.com"
        echo "Example: $0 MILDCASINO mildcasino-new.com custom-main.com yes"
        exit 1
    fi
    
    # Initialize
    init_directories
    create_template
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Check if brand exists
    if ! brand_exists "$brand"; then
        echo "Error: Brand '$brand' not found"
        echo "Available brands: $(get_all_brands | tr '\n' ' ')"
        exit 1
    fi
    
    # Get main domain
    if [[ -z "$main_domain" ]]; then
        main_domain=$(get_main_domain "$brand")
        if [[ -z "$main_domain" ]]; then
            echo "Error: No main domain found for brand '$brand'"
            echo "Please specify main domain as third parameter"
            exit 1
        fi
    fi
    
    # Create vhost file
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    # Check if file exists
    if [[ -f "$vhost_file" ]]; then
        read -p "File exists. Overwrite? (y/n): " confirm
        [[ "$confirm" != "y" ]] && exit 0
    fi
    
    # Generate vhost content
    sed -e "s/{{FRESH_DOMAIN}}/$fresh_domain/g" \
        -e "s/{{MAIN_DOMAIN}}/$main_domain/g" \
        "$TEMPLATE_FILE" > "$vhost_file"
    
    echo "✓ Created: $vhost_file"
    echo "✓ Fresh domain: $fresh_domain"
    echo "✓ Main domain: $main_domain"
    echo "✓ Brand: $brand"
    
    # Ask about SSL generation if not specified
    local run_ssl="$auto_ssl"
    if [[ "$auto_ssl" == "ask" ]]; then
        echo ""
        read -p "Generate SSL certificate automatically? (y/n): " ssl_confirm
        if [[ "$ssl_confirm" == "y" || "$ssl_confirm" == "Y" ]]; then
            run_ssl="yes"
        else
            run_ssl="no"
        fi
    fi
    
    # Generate SSL certificate if requested
    if [[ "$run_ssl" == "yes" ]]; then
        if generate_ssl_certificate "$fresh_domain"; then
            # Ask about creating symlink
            echo ""
            read -p "Create nginx symlink and reload? (y/n): " symlink_confirm
            if [[ "$symlink_confirm" == "y" || "$symlink_confirm" == "Y" ]]; then
                if create_nginx_symlink "$fresh_domain" "$vhost_file"; then
                    reload_nginx
                fi
            fi
        fi
    else
        echo ""
        echo "Manual steps required:"
        echo "1. Generate SSL: certbotcf certonly --dns-cloudflare --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini -d \"$fresh_domain\" -d \"*.$fresh_domain\""
        echo "2. Create symlink: sudo ln -s $vhost_file /etc/nginx/sites-enabled/"
        echo "3. Test nginx: sudo nginx -t"
        echo "4. Reload nginx: sudo systemctl reload nginx"
    fi
}

# Function to delete fresh vhost
delete_fresh_vhost() {
    local fresh_domain=$1
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: delete_fresh_vhost <FRESH_DOMAIN>"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    local symlink_file="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    # Check if vhost file exists
    if [[ ! -f "$vhost_file" ]]; then
        echo "Error: Fresh vhost file not found: $vhost_file"
        return 1
    fi
    
    echo "Found fresh vhost file: $vhost_file"
    
    # Check for symlink
    if [[ -L "$symlink_file" ]]; then
        echo "Found nginx symlink: $symlink_file"
        read -p "Remove nginx symlink too? (y/n): " remove_symlink
        if [[ "$remove_symlink" == "y" || "$remove_symlink" == "Y" ]]; then
            rm "$symlink_file" && echo "✓ Removed symlink: $symlink_file"
        fi
    fi
    
    # Confirm deletion
    read -p "Delete fresh vhost file '$fresh_domain'? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm "$vhost_file"
        echo "✓ Deleted: $vhost_file"
    else
        echo "Deletion cancelled"
    fi
}

# Function to list fresh vhosts
list_fresh_vhosts() {
    echo "Fresh VHost Files"
    echo "================="
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "No vhost directory found"
        return
    fi
    
    local count=0
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            local symlink="/etc/nginx/sites-enabled/$filename"
            
            printf "%-40s" "$domain"
            if [[ -L "$symlink" ]]; then
                echo " [ENABLED]"
            else
                echo " [DISABLED]"
            fi
            ((count++))
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "No fresh vhost files found"
    else
        echo ""
        echo "Total: $count files"
    fi
}

# Function to select fresh domain from database
select_fresh_domain_from_db() {
    echo "Select Brand:"
    echo "============="
    
    local brands=($(get_all_brands))
    if [[ ${#brands[@]} -eq 0 ]]; then
        echo "No brands found in database"
        return 1
    fi
    
    # Show brands
    for i in "${!brands[@]}"; do
        local brand="${brands[$i]}"
        local fresh_count=$(get_domain_count "$brand" "fresh")
        echo "$((i+1)). $brand ($fresh_count fresh domains)"
    done
    echo ""
    
    # Select brand
    read -p "Choose brand (1-${#brands[@]}): " brand_choice
    if [[ ! "$brand_choice" =~ ^[0-9]+$ ]] || [[ $brand_choice -lt 1 ]] || [[ $brand_choice -gt ${#brands[@]} ]]; then
        echo "Invalid brand selection"
        return 1
    fi
    
    local selected_brand="${brands[$((brand_choice-1))]}"
    
    # Get fresh domains for selected brand
    local fresh_domains=$(get_brand_domains "$selected_brand" "fresh")
    if [[ $? -ne 0 || -z "$fresh_domains" ]]; then
        echo "No fresh domains found for brand $selected_brand"
        return 1
    fi
    
    echo ""
    echo "Fresh domains for $selected_brand:"
    echo "=================================="
    
    IFS=',' read -ra domain_array <<< "$fresh_domains"
    for i in "${!domain_array[@]}"; do
        echo "$((i+1)). ${domain_array[$i]}"
    done
    echo ""
    
    # Select fresh domain
    read -p "Choose fresh domain (1-${#domain_array[@]}): " domain_choice
    if [[ ! "$domain_choice" =~ ^[0-9]+$ ]] || [[ $domain_choice -lt 1 ]] || [[ $domain_choice -gt ${#domain_array[@]} ]]; then
        echo "Invalid domain selection"
        return 1
    fi
    
    local selected_fresh_domain="${domain_array[$((domain_choice-1))]}"
    
    # Get main domain for the brand
    local main_domain=$(get_main_domain "$selected_brand")
    
    echo ""
    echo "Selected:"
    echo "Brand: $selected_brand"
    echo "Fresh domain: $selected_fresh_domain"
    echo "Main domain: $main_domain"
    echo ""
    
    read -p "Create vhost for this fresh domain? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        add_fresh_vhost "$selected_brand" "$selected_fresh_domain" "$main_domain"
    else
        echo "Creation cancelled"
    fi
}

# Interactive menu
show_menu() {
    echo ""
    echo "Fresh VHost Manager"
    echo "=================="
    echo "1. Create fresh vhost (from database)"
    echo "2. Bulk create all fresh vhosts"
    echo "3. Bulk create for specific brand"
    echo "4. Delete fresh vhost"
    echo "5. List fresh vhosts"
    echo "6. Exit"
    echo ""
}

# Interactive mode
interactive_mode() {
    while true; do
        show_menu
        read -p "Choose option (1-6): " choice
        
        case $choice in
            1)
                echo ""
                echo "Create Fresh VHost from Database"
                echo "==============================="
                select_fresh_domain_from_db
                ;;
            2)
                echo ""
                create_bulk_fresh_vhosts
                ;;
            3)
                echo ""
                create_bulk_brand_fresh_vhosts
                ;;
            4)
                echo ""
                echo "Delete Fresh VHost"
                echo "=================="
                list_fresh_vhosts
                echo ""
                read -p "Fresh domain to delete: " fresh_domain
                
                if [[ -n "$fresh_domain" ]]; then
                    echo ""
                    delete_fresh_vhost "$fresh_domain"
                fi
                ;;
            5)
                echo ""
                list_fresh_vhosts
                ;;
            6)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Please choose 1-6."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Main execution
# Main execution
if [[ $# -eq 0 ]]; then
    # No arguments - run interactive mode
    interactive_mode
else
    # Arguments provided - run command line mode
    case $1 in
        "create")
            add_fresh_vhost "$2" "$3" "$4"
            ;;
        "bulk")
            create_bulk_fresh_vhosts
            ;;
        "delete")
            delete_fresh_vhost "$2"
            ;;
        "list")
            list_fresh_vhosts
            ;;
        *)
            add_fresh_vhost "$@"
            ;;
    esac
fi