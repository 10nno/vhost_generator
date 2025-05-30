#!/bin/bash

# Single Operations Functions
# File: single_operations.sh
# Contains single domain operation functionality

# Function to run SSL certificate generation
generate_ssl_certificate() {
    local fresh_domain=$1
    
    # Check if SSL manager script exists
    local ssl_manager_script="$SCRIPT_DIR/ssl_manager.sh"
    
    if [[ -f "$ssl_manager_script" ]]; then
        echo ""
        echo "Using SSL Manager for certificate generation..."
        echo "=============================================="
        
        # Use the SSL manager script
        "$ssl_manager_script" generate "$fresh_domain" "yes" "no"
        return $?
    else
        echo ""
        echo "Generating SSL Certificate (Legacy Mode)..."
        echo "========================================="
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
    fi
}

# Main function to add fresh vhost
add_fresh_vhost() {
    local brand=$1
    local fresh_domain=$2
    local main_domain=$3
    local auto_ssl=${4:-"ask"}  # ask, yes, no
    
    if [[ -z "$brand" || -z "$fresh_domain" ]]; then
        echo "Usage: add_fresh_vhost <BRAND> <FRESH_DOMAIN> [MAIN_DOMAIN] [AUTO_SSL]"
        echo "Example: add_fresh_vhost MILDCASINO mildcasino-new.com"
        echo "Example: add_fresh_vhost MILDCASINO mildcasino-new.com custom-main.com yes"
        return 1
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
        return 1
    fi
    
    # Get main domain
    if [[ -z "$main_domain" ]]; then
        main_domain=$(get_main_domain "$brand")
        if [[ -z "$main_domain" ]]; then
            echo "Error: No main domain found for brand '$brand'"
            echo "Please specify main domain as third parameter"
            return 1
        fi
    fi
    
    # Create vhost file
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    # Check if file exists
    if [[ -f "$vhost_file" ]]; then
        read -p "File exists. Overwrite? (y/n): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 0
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
                # Use new symlink function if available, otherwise fallback to legacy
                if declare -f symlink_fresh_vhost >/dev/null; then
                    if symlink_fresh_vhost "$fresh_domain" "no" "no"; then
                        if declare -f reload_nginx >/dev/null; then
                            reload_nginx
                        else
                            echo "Testing and reloading nginx..."
                            if nginx -t && systemctl reload nginx; then
                                echo "✓ Nginx reloaded successfully"
                            else
                                echo "✗ Failed to reload nginx"
                            fi
                        fi
                    fi
                elif declare -f create_nginx_symlink >/dev/null; then
                    if create_nginx_symlink "$fresh_domain" "$vhost_file"; then
                        if declare -f reload_nginx >/dev/null; then
                            reload_nginx
                        fi
                    fi
                else
                    echo "Manual symlink creation required:"
                    echo "sudo ln -s $vhost_file /etc/nginx/sites-enabled/"
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
    
    return 0
}

# Function to create fresh vhost with full automation
create_fresh_vhost_automated() {
    local brand=$1
    local fresh_domain=$2
    local main_domain=$3
    local enable_ssl=${4:-"yes"}
    local enable_symlink=${5:-"yes"}
    local reload_nginx_flag=${6:-"yes"}
    
    echo "Automated Fresh VHost Creation"
    echo "============================="
    echo "Brand: $brand"
    echo "Fresh Domain: $fresh_domain"
    echo "Main Domain: $main_domain"
    echo "SSL: $enable_ssl"
    echo "Symlink: $enable_symlink"
    echo "Reload Nginx: $reload_nginx_flag"
    echo ""
    
    # Create vhost file
    if ! add_fresh_vhost "$brand" "$fresh_domain" "$main_domain" "$enable_ssl"; then
        echo "✗ Failed to create vhost"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    # Create symlink if requested
    if [[ "$enable_symlink" == "yes" ]]; then
        if declare -f symlink_fresh_vhost >/dev/null; then
            if ! symlink_fresh_vhost "$fresh_domain" "no" "yes"; then
                echo "⚠ Warning: Failed to create symlink"
            fi
        elif declare -f create_nginx_symlink >/dev/null; then
            if ! create_nginx_symlink "$fresh_domain" "$vhost_file"; then
                echo "⚠ Warning: Failed to create symlink"
            fi
        fi
    fi
    
    # Reload nginx if requested
    if [[ "$reload_nginx_flag" == "yes" ]]; then
        if declare -f reload_nginx >/dev/null; then
            if ! reload_nginx; then
                echo "⚠ Warning: Failed to reload nginx"
            fi
        else
            echo "Testing and reloading nginx..."
            if nginx -t && systemctl reload nginx; then
                echo "✓ Nginx reloaded successfully"
            else
                echo "⚠ Warning: Failed to reload nginx"
            fi
        fi
    fi
    
    echo ""
    echo "✓ Automated creation completed for: $fresh_domain"
    return 0
}

# Function to update existing vhost
update_fresh_vhost() {
    local fresh_domain=$1
    local new_main_domain=$2
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: update_fresh_vhost <fresh_domain> [new_main_domain]"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    if [[ ! -f "$vhost_file" ]]; then
        echo "Error: Vhost file not found: $vhost_file"
        return 1
    fi
    
    echo "Update Fresh VHost"
    echo "=================="
    echo "Domain: $fresh_domain"
    echo "Current file: $vhost_file"
    echo ""
    
    # Get current main domain from file
    local current_main_domain=$(grep -o 'proxy_pass http://[^/]*' "$vhost_file" | sed 's/proxy_pass http:\/\///' | head -1)
    echo "Current main domain: $current_main_domain"
    
    # If no new main domain specified, ask for it
    if [[ -z "$new_main_domain" ]]; then
        read -p "Enter new main domain [$current_main_domain]: " new_main_domain
        new_main_domain=${new_main_domain:-$current_main_domain}
    fi
    
    if [[ "$new_main_domain" == "$current_main_domain" ]]; then
        echo "No changes needed - domains are the same"
        return 0
    fi
    
    echo "New main domain: $new_main_domain"
    echo ""
    
    read -p "Update vhost file? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Update cancelled"
        return 0
    fi
    
    # Create backup
    local backup_file="${vhost_file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$vhost_file" "$backup_file"
    echo "✓ Backup created: $backup_file"
    
    # Update the file
    sed -i "s|$current_main_domain|$new_main_domain|g" "$vhost_file"
    
    if [[ $? -eq 0 ]]; then
        echo "✓ Updated vhost file"
        
        # Check if symlink exists and reload nginx
        local symlink_file="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
        if [[ -L "$symlink_file" ]]; then
            echo ""
            read -p "Test and reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                if declare -f reload_nginx >/dev/null; then
                    reload_nginx
                else
                    if nginx -t && systemctl reload nginx; then
                        echo "✓ Nginx reloaded successfully"
                    else
                        echo "✗ Failed to reload nginx"
                    fi
                fi
            fi
        fi
    else
        echo "✗ Failed to update vhost file"
        echo "Restoring from backup..."
        cp "$backup_file" "$vhost_file"
        return 1
    fi
    
    return 0
}

# Function to clone vhost from existing domain
clone_fresh_vhost() {
    local source_domain=$1
    local target_domain=$2
    local new_main_domain=$3
    
    if [[ -z "$source_domain" || -z "$target_domain" ]]; then
        echo "Usage: clone_fresh_vhost <source_domain> <target_domain> [new_main_domain]"
        return 1
    fi
    
    local source_file="$VHOST_DIR/${source_domain}_fresh_vhost"
    local target_file="$VHOST_DIR/${target_domain}_fresh_vhost"
    
    if [[ ! -f "$source_file" ]]; then
        echo "Error: Source vhost file not found: $source_file"
        return 1
    fi
    
    if [[ -f "$target_file" ]]; then
        read -p "Target file exists. Overwrite? (y/n): " confirm
        [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return 0
    fi
    
    echo "Clone Fresh VHost"
    echo "================="
    echo "Source: $source_domain"
    echo "Target: $target_domain"
    echo ""
    
    # Copy the file
    cp "$source_file" "$target_file"
    
    if [[ $? -ne 0 ]]; then
        echo "✗ Failed to copy vhost file"
        return 1
    fi
    
    # Update domain references in the new file
    sed -i "s|$source_domain|$target_domain|g" "$target_file"
    
    # Update main domain if specified
    if [[ -n "$new_main_domain" ]]; then
        local current_main_domain=$(grep -o 'proxy_pass http://[^/]*' "$target_file" | sed 's/proxy_pass http:\/\///' | head -1)
        sed -i "s|$current_main_domain|$new_main_domain|g" "$target_file"
        echo "✓ Updated main domain to: $new_main_domain"
    fi
    
    echo "✓ Cloned vhost: $source_domain → $target_domain"
    
    # Ask about SSL and symlink
    echo ""
    read -p "Generate SSL certificate for $target_domain? (y/n): " ssl_confirm
    if [[ "$ssl_confirm" == "y" || "$ssl_confirm" == "Y" ]]; then
        if generate_ssl_certificate "$target_domain"; then
            read -p "Create nginx symlink and reload? (y/n): " symlink_confirm
            if [[ "$symlink_confirm" == "y" || "$symlink_confirm" == "Y" ]]; then
                if declare -f symlink_fresh_vhost >/dev/null; then
                    if symlink_fresh_vhost "$target_domain" "no" "no"; then
                        if declare -f reload_nginx >/dev/null; then
                            reload_nginx
                        fi
                    fi
                elif declare -f create_nginx_symlink >/dev/null; then
                    if create_nginx_symlink "$target_domain" "$target_file"; then
                        if declare -f reload_nginx >/dev/null; then
                            reload_nginx
                        fi
                    fi
                fi
            fi
        fi
    fi
    
    return 0
}

# Function to validate vhost configuration
validate_fresh_vhost() {
    local fresh_domain=$1
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: validate_fresh_vhost <fresh_domain>"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    if [[ ! -f "$vhost_file" ]]; then
        echo "Error: Vhost file not found: $vhost_file"
        return 1
    fi
    
    echo "Validate Fresh VHost: $fresh_domain"
    echo "==================================="
    echo ""
    
    local errors=0
    local warnings=0
    
    # Check file exists and is readable
    if [[ -r "$vhost_file" ]]; then
        echo "✓ File exists and is readable"
    else
        echo "✗ File is not readable"
        ((errors++))
    fi
    
    # Check for SSL certificate paths
    local ssl_cert_path=$(grep -o '/etc/letsencrypt/live/[^/]*/fullchain.pem' "$vhost_file" | head -1)
    local ssl_key_path=$(grep -o '/etc/letsencrypt/live/[^/]*/privkey.pem' "$vhost_file" | head -1)
    
    if [[ -n "$ssl_cert_path" ]]; then
        if [[ -f "$ssl_cert_path" ]]; then
            echo "✓ SSL certificate file exists: $ssl_cert_path"
        else
            echo "✗ SSL certificate file not found: $ssl_cert_path"
            ((errors++))
        fi
    else
        echo "⚠ No SSL certificate path found in config"
        ((warnings++))
    fi
    
    if [[ -n "$ssl_key_path" ]]; then
        if [[ -f "$ssl_key_path" ]]; then
            echo "✓ SSL private key file exists: $ssl_key_path"
        else
            echo "✗ SSL private key file not found: $ssl_key_path"
            ((errors++))
        fi
    else
        echo "⚠ No SSL private key path found in config"
        ((warnings++))
    fi
    
    # Check for main domain configuration
    local main_domain=$(grep -o 'proxy_pass http://[^/]*' "$vhost_file" | sed 's/proxy_pass http:\/\///' | head -1)
    if [[ -n "$main_domain" ]]; then
        echo "✓ Main domain configured: $main_domain"
    else
        echo "✗ No main domain found in proxy_pass configuration"
        ((errors++))
    fi
    
    # Check nginx symlink
    local symlink_file="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    if [[ -L "$symlink_file" ]]; then
        if [[ -f "$symlink_file" ]]; then
            echo "✓ Nginx symlink exists and is valid"
        else
            echo "✗ Nginx symlink exists but points to non-existent file"
            ((errors++))
        fi
    else
        echo "⚠ No nginx symlink found (vhost is disabled)"
        ((warnings++))
    fi
    
    # Test nginx configuration syntax
    echo ""
    echo "Testing nginx configuration..."
    if nginx -t 2>/dev/null; then
        echo "✓ Nginx configuration syntax is valid"
    else
        echo "✗ Nginx configuration has syntax errors"
        ((errors++))
    fi
    
    # Summary
    echo ""
    echo "Validation Summary"
    echo "=================="
    echo "Errors: $errors"
    echo "Warnings: $warnings"
    
    if [[ $errors -eq 0 ]]; then
        echo "✓ Validation passed"
        return 0
    else
        echo "✗ Validation failed"
        return 1
    fi
}

# Function to show vhost information
show_vhost_info() {
    local fresh_domain=$1
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: show_vhost_info <fresh_domain>"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    
    if [[ ! -f "$vhost_file" ]]; then
        echo "Error: Vhost file not found: $vhost_file"
        return 1
    fi
    
    echo "Fresh VHost Information: $fresh_domain"
    echo "======================================"
    echo ""
    
    # Basic info
    echo "File Path: $vhost_file"
    echo "File Size: $(du -h "$vhost_file" | cut -f1)"
    echo "Last Modified: $(stat -c %y "$vhost_file" 2>/dev/null || stat -f %Sm "$vhost_file" 2>/dev/null)"
    echo ""
    
    # Extract configuration details
    local main_domain=$(grep -o 'proxy_pass http://[^/]*' "$vhost_file" | sed 's/proxy_pass http:\/\///' | head -1)
    local ssl_cert_path=$(grep -o '/etc/letsencrypt/live/[^/]*/fullchain.pem' "$vhost_file" | head -1)
    
    echo "Configuration:"
    echo "-------------"
    echo "Fresh Domain: $fresh_domain"
    echo "Main Domain: ${main_domain:-'Not found'}"
    echo "SSL Certificate: ${ssl_cert_path:-'Not configured'}"
    
    # Nginx status
    local symlink_file="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    echo ""
    echo "Nginx Status:"
    echo "------------"
    if [[ -L "$symlink_file" ]]; then
        echo "Status: ENABLED"
        echo "Symlink: $symlink_file"
    else
        echo "Status: DISABLED"
        echo "Symlink: Not found"
    fi
    
    # SSL certificate info
    if [[ -n "$ssl_cert_path" && -f "$ssl_cert_path" ]]; then
        echo ""
        echo "SSL Certificate Info:"
        echo "--------------------"
        local expiry_date=$(openssl x509 -enddate -noout -in "$ssl_cert_path" | cut -d= -f2)
        local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
        local current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        echo "Expires: $expiry_date"
        echo "Days until expiry: $days_until_expiry"
        
        if [[ $days_until_expiry -le 30 ]]; then
            echo "⚠ Certificate expires soon!"
        fi
    fi
    
    return 0
}

# Function to quick create vhost (minimal prompts)
quick_create_fresh_vhost() {
    local fresh_domain=$1
    local brand=$2
    local main_domain=$3
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: quick_create_fresh_vhost <fresh_domain> [brand] [main_domain]"
        echo "Example: quick_create_fresh_vhost newdomain.com BRANDNAME maindomain.com"
        return 1
    fi
    
    echo "Quick Create Fresh VHost"
    echo "======================="
    echo "Domain: $fresh_domain"
    
    # Auto-detect brand if not provided
    if [[ -z "$brand" ]]; then
        if declare -f get_all_brands >/dev/null; then
            local brands=($(get_all_brands))
            if [[ ${#brands[@]} -eq 1 ]]; then
                brand="${brands[0]}"
                echo "Auto-detected brand: $brand"
            else
                echo "Available brands: ${brands[*]}"
                read -p "Enter brand: " brand
            fi
        else
            read -p "Enter brand: " brand
        fi
    fi
    
    # Auto-detect main domain if not provided
    if [[ -z "$main_domain" ]]; then
        if declare -f get_main_domain >/dev/null; then
            main_domain=$(get_main_domain "$brand")
            if [[ -n "$main_domain" ]]; then
                echo "Auto-detected main domain: $main_domain"
            fi
        fi
        
        if [[ -z "$main_domain" ]]; then
            read -p "Enter main domain: " main_domain
        fi
    fi
    
    echo ""
    echo "Creating vhost with:"
    echo "Brand: $brand"
    echo "Fresh Domain: $fresh_domain"
    echo "Main Domain: $main_domain"
    echo ""
    
    # Create with automation
    create_fresh_vhost_automated "$brand" "$fresh_domain" "$main_domain" "yes" "yes" "yes"
    
    return $?
}

# Function to batch process multiple domains
batch_create_fresh_vhosts() {
    local domains_file=$1
    local brand=$2
    local main_domain=$3
    
    if [[ -z "$domains_file" ]]; then
        echo "Usage: batch_create_fresh_vhosts <domains_file> [brand] [main_domain]"
        echo "File format: one domain per line"
        return 1
    fi
    
    if [[ ! -f "$domains_file" ]]; then
        echo "Error: Domains file not found: $domains_file"
        return 1
    fi
    
    echo "Batch Create Fresh VHosts"
    echo "========================"
    echo "Domains file: $domains_file"
    echo ""
    
    # Count domains
    local domain_count=$(grep -v '^#' "$domains_file" | grep -v '^$' | wc -l)
    echo "Found $domain_count domains to process"
    
    if [[ $domain_count -eq 0 ]]; then
        echo "No domains found in file"
        return 1
    fi
    
    read -p "Proceed with batch creation? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Batch creation cancelled"
        return 0
    fi
    
    local success_count=0
    local failed_count=0
    
    echo ""
    echo "Processing domains..."
    echo "===================="
    
    while IFS= read -r domain; do
        # Skip comments and empty lines
        [[ "$domain" =~ ^#.*$ ]] && continue
        [[ -z "$domain" ]] && continue
        
        # Trim whitespace
        domain=$(echo "$domain" | xargs)
        
        echo ""
        echo "Processing: $domain"
        echo "-------------------"
        
        if quick_create_fresh_vhost "$domain" "$brand" "$main_domain"; then
            ((success_count++))
            echo "✓ Success: $domain"
        else
            ((failed_count++))
            echo "✗ Failed: $domain"
        fi
    done < "$domains_file"
    
    echo ""
    echo "Batch Creation Summary"
    echo "====================="
    echo "✓ Success: $success_count"
    echo "✗ Failed: $failed_count"
    echo "Total: $((success_count + failed_count))"
    
    return 0
}