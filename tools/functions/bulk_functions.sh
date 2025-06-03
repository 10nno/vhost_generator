#!/bin/bash

# Bulk Operations Functions
# File: bulk_functions.sh
# Contains bulk operation functionality

# Function to get main domain for a brand
get_main_domain() {
    local brand=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    local main_domains=$(get_brand_domains "$brand" "main")
    if [[ $? -eq 0 && -n "$main_domains" ]]; then
        IFS=',' read -ra domain_array <<< "$main_domains"
        echo "${domain_array[0]}"
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
                        if declare -f create_nginx_symlink >/dev/null; then
                            create_nginx_symlink "$fresh_domain" "$vhost_file"
                        elif declare -f symlink_fresh_vhost >/dev/null; then
                            symlink_fresh_vhost "$fresh_domain" "no" "no"
                        fi
                    fi
                fi
            done
            
            echo ""
            read -p "Test and reload nginx? (y/n): " reload_confirm
            if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
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
        fi
    fi
}

# Function to bulk delete vhosts
bulk_delete_fresh_vhosts() {
    echo "Bulk Delete Fresh VHosts"
    echo "========================"
    echo ""
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "No vhost directory found"
        return 0
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
    
    # Show current vhosts
    if declare -f list_fresh_vhosts >/dev/null; then
        list_fresh_vhosts
    else
        echo "Fresh VHost Files:"
        echo "=================="
        for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
            if [[ -f "$vhost_file" ]]; then
                local filename=$(basename "$vhost_file")
                local domain="${filename%_fresh_vhost}"
                echo "• $domain"
            fi
        done
    fi
    
    echo ""
    echo "Found $vhost_count fresh vhost files"
    echo ""
    echo "Delete options:"
    echo "1. Delete all vhost files"
    echo "2. Delete enabled vhost files only"
    echo "3. Delete disabled vhost files only"
    echo "4. Select specific files to delete"
    echo ""
    read -p "Choose option (1-4): " delete_choice
    
    local files_to_delete=()
    
    case $delete_choice in
        1)
            # Delete all
            for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
                [[ -f "$vhost_file" ]] && files_to_delete+=("$(basename "$vhost_file")")
            done
            ;;
        2)
            # Delete enabled only
            for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
                if [[ -f "$vhost_file" ]]; then
                    local filename=$(basename "$vhost_file")
                    local symlink="/etc/nginx/sites-enabled/$filename"
                    [[ -L "$symlink" ]] && files_to_delete+=("$filename")
                fi
            done
            ;;
        3)
            # Delete disabled only
            for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
                if [[ -f "$vhost_file" ]]; then
                    local filename=$(basename "$vhost_file")
                    local symlink="/etc/nginx/sites-enabled/$filename"
                    [[ ! -L "$symlink" ]] && files_to_delete+=("$filename")
                fi
            done
            ;;
        4)
            # Select specific files
            echo ""
            echo "Select files to delete (space-separated numbers):"
            echo "================================================="
            
            local file_list=()
            local index=1
            for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
                if [[ -f "$vhost_file" ]]; then
                    local filename=$(basename "$vhost_file")
                    local domain="${filename%_fresh_vhost}"
                    echo "$index. $domain"
                    file_list+=("$filename")
                    ((index++))
                fi
            done
            
            echo ""
            read -p "Enter numbers (e.g., 1 3 5): " selected_numbers
            
            for num in $selected_numbers; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -ge 1 ]] && [[ $num -le ${#file_list[@]} ]]; then
                    files_to_delete+=("${file_list[$((num-1))]}")
                fi
            done
            ;;
        *)
            echo "Invalid option"
            return 1
            ;;
    esac
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        echo "No files selected for deletion"
        return 0
    fi
    
    echo ""
    echo "Files to be deleted:"
    echo "==================="
    for filename in "${files_to_delete[@]}"; do
        local domain="${filename%_fresh_vhost}"
        echo "• $domain"
    done
    
    echo ""
    read -p "Are you sure you want to delete ${#files_to_delete[@]} files? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Bulk deletion cancelled"
        return 0
    fi
    
    # Ask about symlinks
    read -p "Also remove nginx symlinks? (y/n): " remove_symlinks
    
    local deleted_count=0
    local failed_count=0
    
    echo ""
    echo "Deleting files..."
    echo "================="
    
    for filename in "${files_to_delete[@]}"; do
        local domain="${filename%_fresh_vhost}"
        local vhost_file="$VHOST_DIR/$filename"
        local symlink_file="/etc/nginx/sites-enabled/$filename"
        
        # Remove symlink if requested
        if [[ "$remove_symlinks" == "y" || "$remove_symlinks" == "Y" ]]; then
            if [[ -L "$symlink_file" ]]; then
                rm "$symlink_file" && echo "✓ Removed symlink: $domain"
            fi
        fi
        
        # Remove vhost file
        if rm "$vhost_file" 2>/dev/null; then
            echo "✓ Deleted: $domain"
            ((deleted_count++))
        else
            echo "✗ Failed to delete: $domain"
            ((failed_count++))
        fi
    done
    
    echo ""
    echo "Bulk Deletion Summary"
    echo "===================="
    echo "✓ Deleted: $deleted_count files"
    echo "✗ Failed: $failed_count files"
    echo "Total processed: $((deleted_count + failed_count)) files"
    
    if [[ $deleted_count -gt 0 ]] && [[ "$remove_symlinks" == "y" || "$remove_symlinks" == "Y" ]]; then
        echo ""
        read -p "Test and reload nginx? (y/n): " reload_confirm
        if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
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
    fi
}

# Function to bulk backup vhosts
bulk_backup_fresh_vhosts() {
    local backup_dir=${1:-"$MAIN_DIR/backup/vhosts"}
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$backup_dir/fresh_vhosts_$timestamp"
    
    echo "Bulk Backup Fresh VHosts"
    echo "========================"
    echo ""
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo "No vhost directory found"
        return 0
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
    echo "Backup destination: $backup_path"
    echo ""
    
    read -p "Create backup of all fresh vhost files? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Backup cancelled"
        return 0
    fi
    
    # Create backup directory
    mkdir -p "$backup_path"
    if [[ $? -ne 0 ]]; then
        echo "✗ Failed to create backup directory: $backup_path"
        return 1
    fi
    
    local backed_up_count=0
    local failed_count=0
    
    echo ""
    echo "Creating backup..."
    echo "=================="
    
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            
            if cp "$vhost_file" "$backup_path/"; then
                echo "✓ Backed up: $domain"
                ((backed_up_count++))
            else
                echo "✗ Failed to backup: $domain"
                ((failed_count++))
            fi
        fi
    done
    
    # Create backup manifest
    local manifest_file="$backup_path/backup_manifest.txt"
    cat > "$manifest_file" << EOF
Fresh VHost Backup Manifest
===========================
Backup Date: $(date)
Source Directory: $VHOST_DIR
Total Files: $((backed_up_count + failed_count))
Successfully Backed Up: $backed_up_count
Failed: $failed_count

Files:
------
EOF
    
    for vhost_file in "$backup_path"/*_fresh_vhost; do
        [[ -f "$vhost_file" ]] && echo "$(basename "$vhost_file")" >> "$manifest_file"
    done
    
    echo ""
    echo "Backup Summary"
    echo "=============="
    echo "✓ Backed up: $backed_up_count files"
    echo "✗ Failed: $failed_count files"
    echo "Backup location: $backup_path"
    echo "Manifest: $manifest_file"
    
    return 0
}

# Function to restore from backup
restore_fresh_vhosts_from_backup() {
    local backup_dir=${1:-"$MAIN_DIR/backup/vhosts"}
    
    echo "Restore Fresh VHosts from Backup"
    echo "================================"
    echo ""
    
    if [[ ! -d "$backup_dir" ]]; then
        echo "Backup directory not found: $backup_dir"
        return 1
    fi
    
    # List available backups
    local backups=()
    for backup_path in "$backup_dir"/fresh_vhosts_*; do
        [[ -d "$backup_path" ]] && backups+=("$(basename "$backup_path")")
    done
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "No backups found in: $backup_dir"
        return 1
    fi
    
    echo "Available backups:"
    echo "=================="
    for i in "${!backups[@]}"; do
        local backup_name="${backups[$i]}"
        local backup_path="$backup_dir/$backup_name"
        local file_count=$(ls -1 "$backup_path"/*_fresh_vhost 2>/dev/null | wc -l)
        echo "$((i+1)). $backup_name ($file_count files)"
    done
    echo ""
    
    read -p "Choose backup to restore (1-${#backups[@]}): " backup_choice
    if [[ ! "$backup_choice" =~ ^[0-9]+$ ]] || [[ $backup_choice -lt 1 ]] || [[ $backup_choice -gt ${#backups[@]} ]]; then
        echo "Invalid backup selection"
        return 1
    fi
    
    local selected_backup="${backups[$((backup_choice-1))]}"
    local backup_path="$backup_dir/$selected_backup"
    
    # Show backup info
    if [[ -f "$backup_path/backup_manifest.txt" ]]; then
        echo ""
        echo "Backup Information:"
        echo "=================="
        cat "$backup_path/backup_manifest.txt"
        echo ""
    fi
    
    # Count files to restore
    local restore_count=0
    for vhost_file in "$backup_path"/*_fresh_vhost; do
        [[ -f "$vhost_file" ]] && ((restore_count++))
    done
    
    echo "Files to restore: $restore_count"
    echo ""
    
    read -p "Restore $restore_count files from $selected_backup? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Restore cancelled"
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
    
    # Ensure target directory exists
    mkdir -p "$VHOST_DIR"
    
    local restored_count=0
    local skipped_count=0
    local failed_count=0
    
    echo ""
    echo "Restoring files..."
    echo "=================="
    
    for vhost_file in "$backup_path"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"
            local target_file="$VHOST_DIR/$filename"
            
            # Check if file exists
            if [[ -f "$target_file" ]]; then
                case $overwrite_policy in
                    "ask")
                        read -p "File exists: $domain. Overwrite? (y/n): " file_confirm
                        if [[ "$file_confirm" != "y" && "$file_confirm" != "Y" ]]; then
                            echo "⚠ Skipped: $domain"
                            ((skipped_count++))
                            continue
                        fi
                        ;;
                    "no")
                        echo "⚠ Skipped (exists): $domain"
                        ((skipped_count++))
                        continue
                        ;;
                    "yes")
                        # Continue to copy
                        ;;
                esac
            fi
            
            # Copy file
            if cp "$vhost_file" "$target_file"; then
                echo "✓ Restored: $domain"
                ((restored_count++))
            else
                echo "✗ Failed: $domain"
                ((failed_count++))
            fi
        fi
    done
    
    echo ""
    echo "Restore Summary"
    echo "==============="
    echo "✓ Restored: $restored_count files"
    echo "⚠ Skipped: $skipped_count files"
    echo "✗ Failed: $failed_count files"
    echo "Total processed: $((restored_count + skipped_count + failed_count)) files"
    
    return 0
}