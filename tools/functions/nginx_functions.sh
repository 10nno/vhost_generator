#!/bin/bash

# Nginx Management Functions
# File: nginx_functions.sh
# Contains nginx-related functionality

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

# Function to check nginx status
check_nginx_status() {
    echo "Nginx Status"
    echo "============"
    
    # Check if nginx is running
    if systemctl is-active --quiet nginx; then
        echo "✓ Nginx is running"
    else
        echo "✗ Nginx is not running"
        return 1
    fi
    
    # Check if nginx is enabled
    if systemctl is-enabled --quiet nginx; then
        echo "✓ Nginx is enabled to start on boot"
    else
        echo "⚠ Nginx is not enabled to start on boot"
    fi
    
    # Test configuration
    echo ""
    echo "Configuration Test:"
    nginx -t
    
    return $?
}

# Function to enable/disable vhost
toggle_vhost() {
    local fresh_domain=$1
    local action=${2:-"toggle"}  # enable, disable, toggle
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: toggle_vhost <fresh_domain> [enable|disable|toggle]"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    local symlink_path="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    # Check if vhost file exists
    if [[ ! -f "$vhost_file" ]]; then
        echo "Error: Vhost file not found: $vhost_file"
        return 1
    fi
    
    # Determine current status
    local is_enabled=false
    if [[ -L "$symlink_path" ]]; then
        is_enabled=true
    fi
    
    # Determine action
    case $action in
        "enable")
            if [[ "$is_enabled" == true ]]; then
                echo "✓ $fresh_domain is already enabled"
                return 0
            fi
            ;;
        "disable")
            if [[ "$is_enabled" == false ]]; then
                echo "✓ $fresh_domain is already disabled"
                return 0
            fi
            ;;
        "toggle"|*)
            # Default toggle behavior
            ;;
    esac
    
    # Perform action
    if [[ "$is_enabled" == true ]] && [[ "$action" != "enable" ]]; then
        # Disable
        rm "$symlink_path"
        if [[ $? -eq 0 ]]; then
            echo "✓ Disabled: $fresh_domain"
        else
            echo "✗ Failed to disable: $fresh_domain"
            return 1
        fi
    elif [[ "$is_enabled" == false ]] && [[ "$action" != "disable" ]]; then
        # Enable
        ln -s "$vhost_file" "$symlink_path"
        if [[ $? -eq 0 ]]; then
            echo "✓ Enabled: $fresh_domain"
        else
            echo "✗ Failed to enable: $fresh_domain"
            return 1
        fi
    fi
    
    return 0
}

# Function to list enabled/disabled vhosts
list_vhost_status() {
    echo "Fresh VHost Status"
    echo "=================="
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "No vhost directory found"
        return
    fi
    
    local enabled_count=0
    local disabled_count=0
    
    printf "%-40s %s\n" "Domain" "Status"
    printf "%-40s %s\n" "------" "------"
    
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            local symlink="/etc/nginx/sites-enabled/$filename"
            
            if [[ -L "$symlink" ]]; then
                printf "%-40s \033[32mENABLED\033[0m\n" "$domain"
                ((enabled_count++))
            else
                printf "%-40s \033[31mDISABLED\033[0m\n" "$domain"
                ((disabled_count++))
            fi
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "--------"
    echo "Enabled: $enabled_count"
    echo "Disabled: $disabled_count"
    echo "Total: $((enabled_count + disabled_count))"
}

# Function to bulk enable/disable vhosts
bulk_toggle_vhosts() {
    local action=$1  # enable, disable
    
    if [[ "$action" != "enable" && "$action" != "disable" ]]; then
        echo "Usage: bulk_toggle_vhosts <enable|disable>"
        return 1
    fi
    
    echo "Bulk $action Fresh VHosts"
    echo "========================="
    echo ""
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "No vhost directory found"
        return
    fi
    
    # Count vhosts
    local vhost_count=0
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        [[ -f "$vhost_file" ]] && ((vhost_count++))
    done
    
    if [[ $vhost_count -eq 0 ]]; then
        echo "No fresh vhost files found"
        return 0
    fi
    
    echo "Found $vhost_count fresh vhost files"
    read -p "Bulk $action all fresh vhosts? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Bulk $action cancelled"
        return 0
    fi
    
    local success_count=0
    local failed_count=0
    
    echo ""
    echo "Processing..."
    echo "============="
    
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            
            if toggle_vhost "$domain" "$action"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        fi
    done
    
    echo ""
    echo "Bulk $action Summary"
    echo "==================="
    echo "✓ Success: $success_count"
    echo "✗ Failed: $failed_count"
    echo "Total: $((success_count + failed_count))"
    
    if [[ $success_count -gt 0 ]]; then
        echo ""
        read -p "Test and reload nginx? (y/n): " reload_confirm
        if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
            reload_nginx
        fi
    fi
}