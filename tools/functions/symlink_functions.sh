#!/bin/bash

# Enhanced Symlink Functions for Fresh VHosts
# File: symlink_functions.sh (or add to nginx_functions.sh)
# Comprehensive symlink management for fresh vhosts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to create symlink for fresh vhost
symlink_fresh_vhost() {
    local fresh_domain=$1
    local force=${2:-"no"}  # yes, no
    local quiet=${3:-"no"}  # yes, no
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: symlink_fresh_vhost <fresh_domain> [force] [quiet]"
        echo "Example: symlink_fresh_vhost example.com yes no"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    local symlink_path="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    [[ "$quiet" != "yes" ]] && echo -e "${BLUE}Creating Symlink for Fresh VHost${NC}"
    [[ "$quiet" != "yes" ]] && echo "=================================="
    [[ "$quiet" != "yes" ]] && echo "Domain: $fresh_domain"
    [[ "$quiet" != "yes" ]] && echo "Source: $vhost_file"
    [[ "$quiet" != "yes" ]] && echo "Target: $symlink_path"
    [[ "$quiet" != "yes" ]] && echo ""
    
    # Check if source vhost file exists
    if [[ ! -f "$vhost_file" ]]; then
        echo -e "${RED}✗ Error: Fresh vhost file not found: $vhost_file${NC}"
        return 1
    fi
    
    # Check if nginx sites-enabled directory exists
    if [[ ! -d "/etc/nginx/sites-enabled" ]]; then
        echo -e "${RED}✗ Error: Nginx sites-enabled directory not found${NC}"
        echo "Please ensure nginx is properly installed"
        return 1
    fi
    
    # Check if symlink already exists
    if [[ -L "$symlink_path" ]]; then
        if [[ "$force" == "yes" ]]; then
            [[ "$quiet" != "yes" ]] && echo -e "${YELLOW}⚠ Removing existing symlink${NC}"
            rm "$symlink_path"
        else
            echo -e "${YELLOW}⚠ Symlink already exists: $symlink_path${NC}"
            
            # Check if it points to the correct file
            local current_target=$(readlink "$symlink_path")
            if [[ "$current_target" == "$vhost_file" ]]; then
                echo -e "${GREEN}✓ Symlink already points to correct file${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ Symlink points to different file: $current_target${NC}"
                if [[ "$quiet" != "yes" ]]; then
                    read -p "Replace existing symlink? (y/n): " recreate
                    if [[ "$recreate" != "y" && "$recreate" != "Y" ]]; then
                        echo "Symlink creation cancelled"
                        return 0
                    fi
                else
                    return 1
                fi
                rm "$symlink_path"
            fi
        fi
    elif [[ -e "$symlink_path" ]]; then
        echo -e "${RED}✗ Error: File exists but is not a symlink: $symlink_path${NC}"
        return 1
    fi
    
    # Create the symlink
    if ln -s "$vhost_file" "$symlink_path" 2>/dev/null; then
        echo -e "${GREEN}✓ Created symlink successfully${NC}"
        [[ "$quiet" != "yes" ]] && echo "  Source: $vhost_file"
        [[ "$quiet" != "yes" ]] && echo "  Target: $symlink_path"
        return 0
    else
        echo -e "${RED}✗ Failed to create symlink${NC}"
        echo "You may need to run with sudo permissions:"
        echo "sudo ln -s \"$vhost_file\" \"$symlink_path\""
        return 1
    fi
}

# Function to remove symlink for fresh vhost
unsymlink_fresh_vhost() {
    local fresh_domain=$1
    local quiet=${2:-"no"}  # yes, no
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: unsymlink_fresh_vhost <fresh_domain> [quiet]"
        return 1
    fi
    
    local symlink_path="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    [[ "$quiet" != "yes" ]] && echo -e "${BLUE}Removing Symlink for Fresh VHost${NC}"
    [[ "$quiet" != "yes" ]] && echo "================================="
    [[ "$quiet" != "yes" ]] && echo "Domain: $fresh_domain"
    [[ "$quiet" != "yes" ]] && echo "Symlink: $symlink_path"
    [[ "$quiet" != "yes" ]] && echo ""
    
    # Check if symlink exists
    if [[ ! -L "$symlink_path" ]]; then
        if [[ -e "$symlink_path" ]]; then
            echo -e "${RED}✗ Error: File exists but is not a symlink: $symlink_path${NC}"
            return 1
        else
            echo -e "${YELLOW}⚠ Symlink does not exist: $symlink_path${NC}"
            return 0
        fi
    fi
    
    # Remove the symlink
    if rm "$symlink_path" 2>/dev/null; then
        echo -e "${GREEN}✓ Removed symlink successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to remove symlink${NC}"
        echo "You may need to run with sudo permissions:"
        echo "sudo rm \"$symlink_path\""
        return 1
    fi
}

# Function to check symlink status
check_symlink_status() {
    local fresh_domain=$1
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: check_symlink_status <fresh_domain>"
        return 1
    fi
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    local symlink_path="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    
    echo "Symlink Status for: $fresh_domain"
    echo "=================================="
    echo "VHost file: $vhost_file"
    echo "Symlink path: $symlink_path"
    echo ""
    
    # Check vhost file
    if [[ -f "$vhost_file" ]]; then
        echo -e "${GREEN}✓ VHost file exists${NC}"
    else
        echo -e "${RED}✗ VHost file not found${NC}"
    fi
    
    # Check symlink
    if [[ -L "$symlink_path" ]]; then
        local target=$(readlink "$symlink_path")
        echo -e "${GREEN}✓ Symlink exists${NC}"
        echo "  Points to: $target"
        
        # Check if symlink is valid
        if [[ -f "$symlink_path" ]]; then
            echo -e "${GREEN}✓ Symlink is valid${NC}"
        else
            echo -e "${RED}✗ Symlink is broken${NC}"
        fi
        
        # Check if symlink points to correct file
        if [[ "$target" == "$vhost_file" ]]; then
            echo -e "${GREEN}✓ Symlink points to correct file${NC}"
        else
            echo -e "${YELLOW}⚠ Symlink points to different file${NC}"
        fi
        
        return 0
    elif [[ -e "$symlink_path" ]]; then
        echo -e "${RED}✗ File exists but is not a symlink${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ Symlink does not exist (vhost is disabled)${NC}"
        return 2
    fi
}

# Function to bulk create symlinks for all fresh vhosts
bulk_symlink_fresh_vhosts() {
    local force=${1:-"no"}  # yes, no
    local test_nginx=${2:-"yes"}  # yes, no
    
    echo -e "${BLUE}Bulk Create Symlinks for Fresh VHosts${NC}"
    echo "====================================="
    echo ""
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo -e "${RED}✗ VHost directory not found: $VHOST_DIR${NC}"
        return 1
    fi
    
    # Count vhost files
    local vhost_count=0
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        [[ -f "$vhost_file" ]] && ((vhost_count++))
    done
    
    if [[ $vhost_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No fresh vhost files found${NC}"
        return 0
    fi
    
    echo "Found $vhost_count fresh vhost files"
    
    if [[ "$force" != "yes" ]]; then
        read -p "Create symlinks for all fresh vhosts? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            echo "Bulk symlink creation cancelled"
            return 0
        fi
    fi
    
    local success_count=0
    local failed_count=0
    local skipped_count=0
    
    echo ""
    echo "Creating symlinks..."
    echo "==================="
    
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            
            echo -n "Processing: $domain ... "
            
            if symlink_fresh_vhost "$domain" "$force" "yes"; then
                echo -e "${GREEN}✓${NC}"
                ((success_count++))
            else
                local symlink_path="/etc/nginx/sites-enabled/${domain}_fresh_vhost"
                if [[ -L "$symlink_path" ]]; then
                    echo -e "${YELLOW}⚠ (exists)${NC}"
                    ((skipped_count++))
                else
                    echo -e "${RED}✗${NC}"
                    ((failed_count++))
                fi
            fi
        fi
    done
    
    echo ""
    echo "Bulk Symlink Summary"
    echo "==================="
    echo -e "${GREEN}✓ Created: $success_count${NC}"
    echo -e "${YELLOW}⚠ Skipped: $skipped_count${NC}"
    echo -e "${RED}✗ Failed: $failed_count${NC}"
    echo "Total processed: $((success_count + skipped_count + failed_count))"
    
    # Test nginx configuration if requested
    if [[ "$test_nginx" == "yes" && $success_count -gt 0 ]]; then
        echo ""
        echo "Testing nginx configuration..."
        if nginx -t 2>/dev/null; then
            echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
            
            read -p "Reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                if systemctl reload nginx 2>/dev/null; then
                    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
                else
                    echo -e "${RED}✗ Failed to reload nginx (may need sudo)${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Nginx configuration has errors${NC}"
            echo "Please fix configuration before reloading nginx"
        fi
    fi
    
    return 0
}

# Function to bulk remove symlinks for fresh vhosts
bulk_unsymlink_fresh_vhosts() {
    local test_nginx=${1:-"yes"}  # yes, no
    
    echo -e "${BLUE}Bulk Remove Symlinks for Fresh VHosts${NC}"
    echo "====================================="
    echo ""
    
    # Count existing symlinks
    local symlink_count=0
    for symlink_file in /etc/nginx/sites-enabled/*_fresh_vhost; do
        [[ -L "$symlink_file" ]] && ((symlink_count++))
    done
    
    if [[ $symlink_count -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No fresh vhost symlinks found${NC}"
        return 0
    fi
    
    echo "Found $symlink_count fresh vhost symlinks"
    read -p "Remove all fresh vhost symlinks? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Bulk symlink removal cancelled"
        return 0
    fi
    
    local success_count=0
    local failed_count=0
    
    echo ""
    echo "Removing symlinks..."
    echo "==================="
    
    for symlink_file in /etc/nginx/sites-enabled/*_fresh_vhost; do
        if [[ -L "$symlink_file" ]]; then
            local filename=$(basename "$symlink_file")
            local domain="${filename%_fresh_vhost}"
            
            echo -n "Removing: $domain ... "
            
            if unsymlink_fresh_vhost "$domain" "yes"; then
                echo -e "${GREEN}✓${NC}"
                ((success_count++))
            else
                echo -e "${RED}✗${NC}"
                ((failed_count++))
            fi
        fi
    done
    
    echo ""
    echo "Bulk Unsymlink Summary"
    echo "====================="
    echo -e "${GREEN}✓ Removed: $success_count${NC}"
    echo -e "${RED}✗ Failed: $failed_count${NC}"
    echo "Total processed: $((success_count + failed_count))"
    
    # Test nginx configuration if requested
    if [[ "$test_nginx" == "yes" && $success_count -gt 0 ]]; then
        echo ""
        echo "Testing nginx configuration..."
        if nginx -t 2>/dev/null; then
            echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
            
            read -p "Reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                if systemctl reload nginx 2>/dev/null; then
                    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
                else
                    echo -e "${RED}✗ Failed to reload nginx (may need sudo)${NC}"
                fi
            fi
        else
            echo -e "${RED}✗ Nginx configuration has errors${NC}"
        fi
    fi
    
    return 0
}

# Function to repair broken symlinks
repair_broken_symlinks() {
    echo -e "${BLUE}Repairing Broken Fresh VHost Symlinks${NC}"
    echo "====================================="
    echo ""
    
    local broken_count=0
    local repaired_count=0
    local removed_count=0
    
    # Check all fresh vhost symlinks
    for symlink_file in /etc/nginx/sites-enabled/*_fresh_vhost; do
        if [[ -L "$symlink_file" ]]; then
            if [[ ! -f "$symlink_file" ]]; then
                local filename=$(basename "$symlink_file")
                local domain="${filename%_fresh_vhost}"
                local expected_target="$VHOST_DIR/${domain}_fresh_vhost"
                
                echo "Found broken symlink: $domain"
                echo "  Symlink: $symlink_file"
                echo "  Current target: $(readlink "$symlink_file")"
                echo "  Expected target: $expected_target"
                
                ((broken_count++))
                
                if [[ -f "$expected_target" ]]; then
                    echo -n "  Repairing ... "
                    if rm "$symlink_file" && ln -s "$expected_target" "$symlink_file"; then
                        echo -e "${GREEN}✓${NC}"
                        ((repaired_count++))
                    else
                        echo -e "${RED}✗${NC}"
                    fi
                else
                    echo -n "  Removing (no target file) ... "
                    if rm "$symlink_file"; then
                        echo -e "${GREEN}✓${NC}"
                        ((removed_count++))
                    else
                        echo -e "${RED}✗${NC}"
                    fi
                fi
                echo ""
            fi
        fi
    done
    
    if [[ $broken_count -eq 0 ]]; then
        echo -e "${GREEN}✓ No broken symlinks found${NC}"
    else
        echo "Repair Summary"
        echo "=============="
        echo "Broken symlinks found: $broken_count"
        echo -e "${GREEN}✓ Repaired: $repaired_count${NC}"
        echo -e "${YELLOW}⚠ Removed: $removed_count${NC}"
        
        if [[ $repaired_count -gt 0 || $removed_count -gt 0 ]]; then
            echo ""
            read -p "Test and reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                if nginx -t && systemctl reload nginx; then
                    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
                else
                    echo -e "${RED}✗ Error reloading nginx${NC}"
                fi
            fi
        fi
    fi
    
    return 0
}

# Function to list all fresh vhost symlinks with status
list_fresh_symlinks() {
    echo "Fresh VHost Symlinks Status"
    echo "==========================="
    echo ""
    
    local enabled_count=0
    local disabled_count=0
    local broken_count=0
    
    printf "%-40s %-15s %s\n" "Domain" "Status" "Target"
    printf "%-40s %-15s %s\n" "------" "------" "------"
    
    # Check all vhost files
    if [[ -d "$VHOST_DIR" ]]; then
        for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
            if [[ -f "$vhost_file" ]]; then
                local filename=$(basename "$vhost_file")
                local domain="${filename%_fresh_vhost}"
                local symlink_path="/etc/nginx/sites-enabled/$filename"
                
                if [[ -L "$symlink_path" ]]; then
                    if [[ -f "$symlink_path" ]]; then
                        printf "%-40s \033[32m%-15s\033[0m %s\n" "$domain" "ENABLED" "$(readlink "$symlink_path")"
                        ((enabled_count++))
                    else
                        printf "%-40s \033[31m%-15s\033[0m %s\n" "$domain" "BROKEN" "$(readlink "$symlink_path")"
                        ((broken_count++))
                    fi
                else
                    printf "%-40s \033[33m%-15s\033[0m %s\n" "$domain" "DISABLED" "-"
                    ((disabled_count++))
                fi
            fi
        done
    fi
    
    echo ""
    echo "Summary:"
    echo "--------"
    echo -e "${GREEN}Enabled: $enabled_count${NC}"
    echo -e "${YELLOW}Disabled: $disabled_count${NC}"
    echo -e "${RED}Broken: $broken_count${NC}"
    echo "Total: $((enabled_count + disabled_count + broken_count))"
    
    if [[ $broken_count -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}⚠ Found $broken_count broken symlinks${NC}"
        echo "Run 'repair_broken_symlinks' to fix them"
    fi
}

# Interactive symlink management menu
interactive_symlink_menu() {
    while true; do
        echo ""
        echo "Fresh VHost Symlink Management"
        echo "============================="
        echo "1. Create symlink for domain"
        echo "2. Remove symlink for domain"
        echo "3. Check symlink status"
        echo "4. List all symlinks"
        echo "5. Bulk create all symlinks"
        echo "6. Bulk remove all symlinks"
        echo "7. Repair broken symlinks"
        echo "8. Back to main menu"
        echo ""
        
        read -p "Choose option (1-8): " choice
        
        case $choice in
            1)
                echo ""
                read -p "Enter domain name: " domain
                if [[ -n "$domain" ]]; then
                    symlink_fresh_vhost "$domain"
                fi
                ;;
            2)
                echo ""
                read -p "Enter domain name: " domain
                if [[ -n "$domain" ]]; then
                    unsymlink_fresh_vhost "$domain"
                fi
                ;;
            3)
                echo ""
                read -p "Enter domain name: " domain
                if [[ -n "$domain" ]]; then
                    check_symlink_status "$domain"
                fi
                ;;
            4)
                echo ""
                list_fresh_symlinks
                ;;
            5)
                echo ""
                bulk_symlink_fresh_vhosts
                ;;
            6)
                echo ""
                bulk_unsymlink_fresh_vhosts
                ;;
            7)
                echo ""
                repair_broken_symlinks
                ;;
            8)
                return 0
                ;;
            *)
                echo "Invalid option. Please choose 1-8."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}