#!/bin/bash

# Interactive Menu Functions
# File: interactive_functions.sh
# Contains interactive menu and user interface functionality

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

# Main interactive menu
show_menu() {
    echo ""
    echo "Fresh VHost Manager"
    echo "=================="
    echo "1. Create fresh vhost (from database)"
    echo "2. Bulk create all fresh vhosts"
    echo "3. Bulk create for specific brand"
    echo "4. Delete fresh vhost"
    echo "5. Bulk delete fresh vhosts"
    echo "6. List fresh vhosts"
    echo "7. Enable/Disable vhost"
    echo "8. Bulk enable/disable vhosts"
    echo "9. Check nginx status"
    echo "10. Backup vhosts"
    echo "11. Restore from backup"
    echo "12. SSL Management"
    echo "13. Symlink management"
    echo "14. Exit"
    echo ""
}

# SSL submenu
show_ssl_menu() {
    echo ""
    echo "SSL Certificate Management"
    echo "========================="
    echo "1. Generate SSL for single domain"
    echo "2. Bulk generate SSL from database"
    echo "3. Check SSL status"
    echo "4. List all certificates"
    echo "5. Renew SSL certificate"
    echo "6. Renew expiring certificates"
    echo "7. Back to main menu"
    echo ""
}

# SSL interactive mode
interactive_ssl_mode() {
    # Check if SSL manager exists
    local ssl_manager_script="$SCRIPT_DIR/ssl_manager.sh"
    
    if [[ -f "$ssl_manager_script" ]]; then
        # Use dedicated SSL manager
        echo "Launching SSL Manager..."
        "$ssl_manager_script"
        return $?
    fi
    
    # Fallback to basic SSL menu
    while true; do
        show_ssl_menu
        read -p "Choose option (1-7): " ssl_choice
        
        case $ssl_choice in
            1)
                echo ""
                echo "Generate SSL Certificate"
                echo "======================="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    generate_ssl_certificate "$domain"
                fi
                ;;
            2)
                echo ""
                echo "Bulk SSL generation requires ssl_manager.sh"
                echo "Please use the dedicated SSL manager script"
                ;;
            3)
                echo ""
                echo "Check SSL Status"
                echo "==============="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    local cert_dir="/etc/letsencrypt/live/$domain"
                    if [[ -d "$cert_dir" ]]; then
                        echo "Certificate found for: $domain"
                        echo "Path: $cert_dir"
                        if [[ -f "$cert_dir/fullchain.pem" ]]; then
                            local expiry_date=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
                            echo "Expires: $expiry_date"
                        fi
                    else
                        echo "No certificate found for: $domain"
                    fi
                fi
                ;;
            4)
                echo ""
                echo "SSL Certificates"
                echo "==============="
                if [[ -d "/etc/letsencrypt/live" ]]; then
                    for cert_dir in "/etc/letsencrypt/live"/*; do
                        if [[ -d "$cert_dir" ]]; then
                            local domain=$(basename "$cert_dir")
                            echo "• $domain"
                        fi
                    done
                else
                    echo "No certificates directory found"
                fi
                ;;
            5|6)
                echo ""
                echo "SSL renewal requires ssl_manager.sh"
                echo "Please use the dedicated SSL manager script"
                ;;
            7)
                return 0
                ;;
            *)
                echo "Invalid option. Please choose 1-7."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Interactive enable/disable menu
interactive_toggle_menu() {
    echo ""
    echo "Enable/Disable VHost"
    echo "==================="
    echo ""
    
    # Show current status
    list_vhost_status
    
    echo ""
    echo "Options:"
    echo "1. Enable specific vhost"
    echo "2. Disable specific vhost"
    echo "3. Toggle specific vhost"
    echo "4. Back to main menu"
    echo ""
    
    read -p "Choose option (1-4): " toggle_choice
    
    case $toggle_choice in
        1|2|3)
            echo ""
            read -p "Enter domain name: " domain
            if [[ -n "$domain" ]]; then
                case $toggle_choice in
                    1) toggle_vhost "$domain" "enable" ;;
                    2) toggle_vhost "$domain" "disable" ;;
                    3) toggle_vhost "$domain" "toggle" ;;
                esac
                
                if [[ $? -eq 0 ]]; then
                    echo ""
                    read -p "Test and reload nginx? (y/n): " reload_confirm
                    if [[ "$reload_confirm" == "y" || "$reload_confirm" == "Y" ]]; then
                        reload_nginx
                    fi
                fi
            fi
            ;;
        4)
            return 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Interactive bulk enable/disable menu
interactive_bulk_toggle_menu() {
    echo ""
    echo "Bulk Enable/Disable VHosts"
    echo "=========================="
    echo ""
    
    # Show current status
    list_vhost_status
    
    echo ""
    echo "Options:"
    echo "1. Enable all vhosts"
    echo "2. Disable all vhosts"
    echo "3. Back to main menu"
    echo ""
    
    read -p "Choose option (1-3): " bulk_choice
    
    case $bulk_choice in
        1)
            bulk_toggle_vhosts "enable"
            ;;
        2)
            bulk_toggle_vhosts "disable"
            ;;
        3)
            return 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Interactive backup menu
interactive_backup_menu() {
    echo ""
    echo "Backup Management"
    echo "================"
    echo ""
    
    echo "Options:"
    echo "1. Create backup"
    echo "2. List backups"
    echo "3. Restore from backup"
    echo "4. Back to main menu"
    echo ""
    
    read -p "Choose option (1-4): " backup_choice
    
    case $backup_choice in
        1)
            echo ""
            read -p "Backup directory [default: $MAIN_DIR/backup/vhosts]: " backup_dir
            backup_dir=${backup_dir:-"$MAIN_DIR/backup/vhosts"}
            bulk_backup_fresh_vhosts "$backup_dir"
            ;;
        2)
            echo ""
            echo "Available Backups"
            echo "================="
            local backup_dir="$MAIN_DIR/backup/vhosts"
            if [[ -d "$backup_dir" ]]; then
                for backup_path in "$backup_dir"/fresh_vhosts_*; do
                    if [[ -d "$backup_path" ]]; then
                        local backup_name=$(basename "$backup_path")
                        local file_count=$(ls -1 "$backup_path"/*_fresh_vhost 2>/dev/null | wc -l)
                        echo "• $backup_name ($file_count files)"
                    fi
                done
            else
                echo "No backup directory found"
            fi
            ;;
        3)
            echo ""
            read -p "Backup directory [default: $MAIN_DIR/backup/vhosts]: " backup_dir
            backup_dir=${backup_dir:-"$MAIN_DIR/backup/vhosts"}
            restore_fresh_vhosts_from_backup "$backup_dir"
            ;;
        4)
            return 0
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Main interactive mode
interactive_mode() {
    while true; do
        show_menu
        read -p "Choose option (1-13): " choice
        
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
                bulk_delete_fresh_vhosts
                ;;
            6)
                echo ""
                list_fresh_vhosts
                ;;
            7)
                interactive_toggle_menu
                ;;
            8)
                interactive_bulk_toggle_menu
                ;;
            9)
                echo ""
                check_nginx_status
                ;;
            10)
                interactive_backup_menu
                ;;
            11)
                echo ""
                read -p "Backup directory [default: $MAIN_DIR/backup/vhosts]: " backup_dir
                backup_dir=${backup_dir:-"$MAIN_DIR/backup/vhosts"}
                restore_fresh_vhosts_from_backup "$backup_dir"
                ;;
            12)
                interactive_ssl_mode
                ;;
            13)
                if declare -f interactive_symlink_menu >/dev/null; then
                    interactive_symlink_menu
                 else
                    echo "Symlink management not available"
                fi
                ;;
            14)
                echo "Goodbye!"
                exit 0
                ;;
            
            *)
                echo "Invalid option. Please choose 1-13."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}