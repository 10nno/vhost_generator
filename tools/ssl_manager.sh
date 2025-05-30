#!/bin/bash

# SSL Certificate Manager Script
# File: ssl_manager.sh
# Handles SSL certificate generation, renewal, and management for domains

# Get the main project directory (parent of tools directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATABASE_DIR="$MAIN_DIR/database"
DATABASE_FILE="$DATABASE_DIR/domains_db.sh"
LOG_DIR="$MAIN_DIR/logs"
SSL_LOG_FILE="$LOG_DIR/ssl_operations.log"

# SSL Configuration
CLOUDFLARE_CREDENTIALS="/etc/letsencrypt/cloudflare.ini"
CERTBOT_CMD="certbotcf"
LETSENCRYPT_DIR="/etc/letsencrypt/live"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Source the database file if it exists
if [[ -f "$DATABASE_FILE" ]]; then
    source "$DATABASE_FILE"
fi

# Function to create log directory
init_logging() {
    [[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"
}

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$SSL_LOG_FILE"
    
    case $level in
        "ERROR")
            echo -e "${RED}✗ $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✓ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ $message${NC}"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    local errors=0
    
    echo "Checking SSL Prerequisites..."
    echo "============================"
    
    # Check if certbotcf command exists
    if ! command -v "$CERTBOT_CMD" &> /dev/null; then
        log_message "ERROR" "certbotcf command not found. Please install certbot-cloudflare"
        ((errors++))
    else
        log_message "SUCCESS" "certbotcf command found"
    fi
    
    # Check if cloudflare credentials file exists
    if [[ ! -f "$CLOUDFLARE_CREDENTIALS" ]]; then
        log_message "ERROR" "Cloudflare credentials file not found: $CLOUDFLARE_CREDENTIALS"
        echo "Please create the file with your Cloudflare API credentials:"
        echo "dns_cloudflare_email = your-email@example.com"
        echo "dns_cloudflare_api_key = your-api-key"
        ((errors++))
    else
        log_message "SUCCESS" "Cloudflare credentials file found"
    fi
    
    # Check if Let's Encrypt directory exists
    if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
        log_message "WARNING" "Let's Encrypt directory not found: $LETSENCRYPT_DIR"
        log_message "INFO" "This is normal if no certificates have been generated yet"
    else
        log_message "SUCCESS" "Let's Encrypt directory found"
    fi
    
    echo ""
    return $errors
}

# Function to generate SSL certificate for a single domain
generate_ssl_certificate() {
    local domain=$1
    local wildcard=${2:-"yes"}  # yes, no
    local force_renew=${3:-"no"}  # yes, no
    
    if [[ -z "$domain" ]]; then
        log_message "ERROR" "Domain not specified"
        return 1
    fi
    
    log_message "INFO" "Starting SSL certificate generation for: $domain"
    
    # Check if certificate already exists
    local cert_dir="$LETSENCRYPT_DIR/$domain"
    if [[ -d "$cert_dir" && "$force_renew" != "yes" ]]; then
        log_message "WARNING" "Certificate already exists for $domain"
        echo "Certificate directory: $cert_dir"
        
        # Check certificate expiry
        if [[ -f "$cert_dir/fullchain.pem" ]]; then
            local expiry_date=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
            local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_until_expiry -gt 30 ]]; then
                log_message "INFO" "Certificate expires in $days_until_expiry days - no renewal needed"
                return 0
            else
                log_message "WARNING" "Certificate expires in $days_until_expiry days - renewal recommended"
            fi
        fi
        
        read -p "Generate new certificate anyway? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_message "INFO" "SSL generation cancelled by user"
            return 0
        fi
    fi
    
    # Prepare certbot command
    local certbot_args="certonly --dns-cloudflare --dns-cloudflare-credentials $CLOUDFLARE_CREDENTIALS"
    
    if [[ "$wildcard" == "yes" ]]; then
        certbot_args="$certbot_args -d \"$domain\" -d \"*.$domain\""
        log_message "INFO" "Generating certificate for: $domain and *.$domain"
    else
        certbot_args="$certbot_args -d \"$domain\""
        log_message "INFO" "Generating certificate for: $domain"
    fi
    
    if [[ "$force_renew" == "yes" ]]; then
        certbot_args="$certbot_args --force-renewal"
        log_message "INFO" "Force renewal enabled"
    fi
    
    # Run the SSL certificate generation
    echo ""
    echo "Running: $CERTBOT_CMD $certbot_args"
    echo ""
    
    eval "$CERTBOT_CMD $certbot_args"
    local ssl_result=$?
    
    if [[ $ssl_result -eq 0 ]]; then
        log_message "SUCCESS" "SSL certificate generated successfully for $domain"
        
        # Verify certificate files
        if [[ -f "$cert_dir/fullchain.pem" && -f "$cert_dir/privkey.pem" ]]; then
            log_message "SUCCESS" "Certificate files verified"
            
            # Show certificate info
            local expiry_date=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
            log_message "INFO" "Certificate expires: $expiry_date"
        else
            log_message "ERROR" "Certificate files not found after generation"
            return 1
        fi
        
        return 0
    else
        log_message "ERROR" "SSL certificate generation failed for $domain"
        log_message "INFO" "Check the logs above for details"
        return 1
    fi
}

# Function to renew SSL certificate
renew_ssl_certificate() {
    local domain=$1
    
    if [[ -z "$domain" ]]; then
        log_message "ERROR" "Domain not specified for renewal"
        return 1
    fi
    
    log_message "INFO" "Renewing SSL certificate for: $domain"
    
    # Check if certificate exists
    local cert_dir="$LETSENCRYPT_DIR/$domain"
    if [[ ! -d "$cert_dir" ]]; then
        log_message "ERROR" "No existing certificate found for $domain"
        log_message "INFO" "Use generate command instead"
        return 1
    fi
    
    # Run renewal
    echo ""
    echo "Running: $CERTBOT_CMD renew --cert-name $domain"
    echo ""
    
    $CERTBOT_CMD renew --cert-name "$domain"
    local renew_result=$?
    
    if [[ $renew_result -eq 0 ]]; then
        log_message "SUCCESS" "SSL certificate renewed successfully for $domain"
        return 0
    else
        log_message "ERROR" "SSL certificate renewal failed for $domain"
        return 1
    fi
}

# Function to check certificate status
check_certificate_status() {
    local domain=$1
    
    if [[ -z "$domain" ]]; then
        echo "Usage: check_certificate_status <domain>"
        return 1
    fi
    
    local cert_dir="$LETSENCRYPT_DIR/$domain"
    
    echo "Certificate Status for: $domain"
    echo "==============================="
    
    if [[ ! -d "$cert_dir" ]]; then
        log_message "ERROR" "No certificate found for $domain"
        return 1
    fi
    
    if [[ ! -f "$cert_dir/fullchain.pem" ]]; then
        log_message "ERROR" "Certificate file not found: $cert_dir/fullchain.pem"
        return 1
    fi
    
    # Certificate details
    echo "Certificate Path: $cert_dir"
    echo ""
    
    # Get certificate information
    local cert_info=$(openssl x509 -in "$cert_dir/fullchain.pem" -text -noout)
    
    # Extract key information
    local subject=$(echo "$cert_info" | grep "Subject:" | sed 's/.*Subject: //')
    local issuer=$(echo "$cert_info" | grep "Issuer:" | sed 's/.*Issuer: //')
    local start_date=$(openssl x509 -startdate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" | cut -d= -f2)
    
    echo "Subject: $subject"
    echo "Issuer: $issuer"
    echo "Valid From: $start_date"
    echo "Valid Until: $expiry_date"
    echo ""
    
    # Calculate days until expiry
    local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    if [[ $days_until_expiry -gt 30 ]]; then
        log_message "SUCCESS" "Certificate is valid for $days_until_expiry more days"
    elif [[ $days_until_expiry -gt 0 ]]; then
        log_message "WARNING" "Certificate expires in $days_until_expiry days - renewal recommended"
    else
        log_message "ERROR" "Certificate has expired!"
    fi
    
    # Show Subject Alternative Names (SAN)
    local san=$(echo "$cert_info" | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/.*DNS://' | sed 's/, DNS:/\n/g')
    if [[ -n "$san" ]]; then
        echo ""
        echo "Subject Alternative Names:"
        echo "$san" | while read -r name; do
            [[ -n "$name" ]] && echo "  • $name"
        done
    fi
    
    return 0
}

# Function to list all certificates
list_certificates() {
    echo "SSL Certificates Overview"
    echo "========================"
    
    if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
        log_message "INFO" "No certificates directory found"
        return 0
    fi
    
    local cert_count=0
    local expiring_count=0
    local expired_count=0
    
    printf "%-30s %-15s %-20s %s\n" "Domain" "Status" "Expires In" "Expiry Date"
    printf "%-30s %-15s %-20s %s\n" "------" "------" "----------" "-----------"
    
    for cert_dir in "$LETSENCRYPT_DIR"/*; do
        if [[ -d "$cert_dir" ]]; then
            local domain=$(basename "$cert_dir")
            local cert_file="$cert_dir/fullchain.pem"
            
            if [[ -f "$cert_file" ]]; then
                local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                local status="Valid"
                local status_color=""
                
                if [[ $days_until_expiry -le 0 ]]; then
                    status="Expired"
                    status_color="$RED"
                    ((expired_count++))
                elif [[ $days_until_expiry -le 30 ]]; then
                    status="Expiring Soon"
                    status_color="$YELLOW"
                    ((expiring_count++))
                else
                    status_color="$GREEN"
                fi
                
                printf "%-30s ${status_color}%-15s${NC} %-20s %s\n" \
                    "$domain" "$status" "${days_until_expiry} days" "$expiry_date"
                
                ((cert_count++))
            fi
        fi
    done
    
    echo ""
    echo "Summary:"
    echo "--------"
    echo "Total certificates: $cert_count"
    if [[ $expired_count -gt 0 ]]; then
        echo -e "${RED}Expired: $expired_count${NC}"
    fi
    if [[ $expiring_count -gt 0 ]]; then
        echo -e "${YELLOW}Expiring soon (≤30 days): $expiring_count${NC}"
    fi
    echo -e "${GREEN}Valid: $((cert_count - expired_count - expiring_count))${NC}"
}

# Function to bulk generate SSL certificates from database
bulk_generate_ssl_from_db() {
    echo "Bulk SSL Certificate Generation from Database"
    echo "============================================"
    echo ""
    
    if [[ ! -f "$DATABASE_FILE" ]]; then
        log_message "ERROR" "Database file not found: $DATABASE_FILE"
        return 1
    fi
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_message "ERROR" "Prerequisites not met. Please fix the issues above."
        return 1
    fi
    
    # Get all brands
    local brands=($(get_all_brands))
    if [[ ${#brands[@]} -eq 0 ]]; then
        log_message "ERROR" "No brands found in database"
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
        log_message "INFO" "No fresh domains found in any brand"
        return 0
    fi
    
    # Ask for confirmation
    read -p "Generate SSL certificates for all $total_fresh fresh domains? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Bulk SSL generation cancelled"
        return 0
    fi
    
    # Ask about wildcard certificates
    read -p "Generate wildcard certificates (*. subdomain)? (y/n): " wildcard_confirm
    local use_wildcard="no"
    if [[ "$wildcard_confirm" == "y" || "$wildcard_confirm" == "Y" ]]; then
        use_wildcard="yes"
    fi
    
    echo ""
    log_message "INFO" "Starting bulk SSL certificate generation..."
    echo ""
    
    local success_count=0
    local failed_count=0
    local skipped_count=0
    
    # Process each brand
    for brand in "${brands[@]}"; do
        echo ""
        log_message "INFO" "Processing brand: $brand"
        echo "------------------------"
        
        # Get fresh domains for this brand
        local fresh_domains=$(get_brand_domains "$brand" "fresh")
        if [[ $? -ne 0 || -z "$fresh_domains" ]]; then
            log_message "WARNING" "No fresh domains found for $brand"
            continue
        fi
        
        # Process each fresh domain
        IFS=',' read -ra domain_array <<< "$fresh_domains"
        for fresh_domain in "${domain_array[@]}"; do
            # Trim whitespace
            fresh_domain=$(echo "$fresh_domain" | xargs)
            
            echo ""
            log_message "INFO" "Processing domain: $fresh_domain"
            
            if generate_ssl_certificate "$fresh_domain" "$use_wildcard" "no"; then
                ((success_count++))
            else
                ((failed_count++))
            fi
        done
    done
    
    # Show summary
    echo ""
    echo "Bulk SSL Generation Summary"
    echo "=========================="
    log_message "SUCCESS" "Successfully generated: $success_count certificates"
    if [[ $failed_count -gt 0 ]]; then
        log_message "ERROR" "Failed to generate: $failed_count certificates"
    fi
    if [[ $skipped_count -gt 0 ]]; then
        log_message "INFO" "Skipped: $skipped_count certificates"
    fi
    echo "Total processed: $((success_count + failed_count + skipped_count)) domains"
}

# Function to renew expiring certificates
renew_expiring_certificates() {
    local days_threshold=${1:-30}
    
    echo "Renewing Certificates Expiring in $days_threshold Days"
    echo "=================================================="
    
    if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
        log_message "INFO" "No certificates directory found"
        return 0
    fi
    
    local renewal_count=0
    local success_count=0
    local failed_count=0
    
    for cert_dir in "$LETSENCRYPT_DIR"/*; do
        if [[ -d "$cert_dir" ]]; then
            local domain=$(basename "$cert_dir")
            local cert_file="$cert_dir/fullchain.pem"
            
            if [[ -f "$cert_file" ]]; then
                local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_until_expiry -le $days_threshold ]]; then
                    echo ""
                    log_message "INFO" "Renewing certificate for $domain (expires in $days_until_expiry days)"
                    
                    ((renewal_count++))
                    
                    if renew_ssl_certificate "$domain"; then
                        ((success_count++))
                    else
                        ((failed_count++))
                    fi
                fi
            fi
        fi
    done
    
    echo ""
    echo "Renewal Summary"
    echo "==============="
    if [[ $renewal_count -eq 0 ]]; then
        log_message "INFO" "No certificates found that expire within $days_threshold days"
    else
        log_message "INFO" "Attempted to renew: $renewal_count certificates"
        log_message "SUCCESS" "Successfully renewed: $success_count certificates"
        if [[ $failed_count -gt 0 ]]; then
            log_message "ERROR" "Failed to renew: $failed_count certificates"
        fi
    fi
}

# Function to delete SSL certificate
delete_ssl_certificate() {
    local domain=$1
    
    if [[ -z "$domain" ]]; then
        echo "Usage: delete_ssl_certificate <domain>"
        return 1
    fi
    
    local cert_dir="$LETSENCRYPT_DIR/$domain"
    
    if [[ ! -d "$cert_dir" ]]; then
        log_message "ERROR" "No certificate found for $domain"
        return 1
    fi
    
    echo "Certificate found for: $domain"
    echo "Path: $cert_dir"
    echo ""
    
    # Show certificate info
    check_certificate_status "$domain"
    
    echo ""
    read -p "Are you sure you want to delete this certificate? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_message "INFO" "Certificate deletion cancelled"
        return 0
    fi
    
    # Delete using certbot
    echo ""
    echo "Running: $CERTBOT_CMD delete --cert-name $domain"
    echo ""
    
    $CERTBOT_CMD delete --cert-name "$domain"
    local delete_result=$?
    
    if [[ $delete_result -eq 0 ]]; then
        log_message "SUCCESS" "SSL certificate deleted successfully for $domain"
        return 0
    else
        log_message "ERROR" "Failed to delete SSL certificate for $domain"
        return 1
    fi
}

# Interactive menu
show_ssl_menu() {
    echo ""
    echo "SSL Certificate Manager"
    echo "======================"
    echo "1. Generate SSL certificate for single domain"
    echo "2. Bulk generate SSL certificates from database"
    echo "3. Renew SSL certificate"
    echo "4. Renew expiring certificates"
    echo "5. Check certificate status"
    echo "6. List all certificates"
    echo "7. Delete SSL certificate"
    echo "8. Check prerequisites"
    echo "9. Exit"
    echo ""
}

# Interactive mode
interactive_ssl_mode() {
    init_logging
    
    while true; do
        show_ssl_menu
        read -p "Choose option (1-9): " choice
        
        case $choice in
            1)
                echo ""
                echo "Generate SSL Certificate"
                echo "======================="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    echo ""
                    read -p "Generate wildcard certificate (*.$domain)? (y/n): " wildcard
                    local use_wildcard="no"
                    [[ "$wildcard" == "y" || "$wildcard" == "Y" ]] && use_wildcard="yes"
                    
                    echo ""
                    generate_ssl_certificate "$domain" "$use_wildcard"
                fi
                ;;
            2)
                echo ""
                bulk_generate_ssl_from_db
                ;;
            3)
                echo ""
                echo "Renew SSL Certificate"
                echo "===================="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    echo ""
                    renew_ssl_certificate "$domain"
                fi
                ;;
            4)
                echo ""
                echo "Renew Expiring Certificates"
                echo "==========================="
                read -p "Days threshold (default 30): " days
                days=${days:-30}
                echo ""
                renew_expiring_certificates "$days"
                ;;
            5)
                echo ""
                echo "Check Certificate Status"
                echo "======================="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    echo ""
                    check_certificate_status "$domain"
                fi
                ;;
            6)
                echo ""
                list_certificates
                ;;
            7)
                echo ""
                echo "Delete SSL Certificate"
                echo "====================="
                read -p "Domain name: " domain
                if [[ -n "$domain" ]]; then
                    echo ""
                    delete_ssl_certificate "$domain"
                fi
                ;;
            8)
                echo ""
                check_prerequisites
                ;;
            9)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo "Invalid option. Please choose 1-9."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Main execution
if [[ $# -eq 0 ]]; then
    # No arguments - run interactive mode
    interactive_ssl_mode
else
    # Arguments provided - run command line mode
    init_logging
    
    case $1 in
        "generate")
            generate_ssl_certificate "$2" "${3:-yes}" "${4:-no}"
            ;;
        "renew")
            renew_ssl_certificate "$2"
            ;;
        "renew-expiring")
            renew_expiring_certificates "${2:-30}"
            ;;
        "check")
            check_certificate_status "$2"
            ;;
        "list")
            list_certificates
            ;;
        "delete")
            delete_ssl_certificate "$2"
            ;;
        "bulk")
            bulk_generate_ssl_from_db
            ;;
        "prerequisites")
            check_prerequisites
            ;;
        *)
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  generate <domain> [wildcard] [force]  - Generate SSL certificate"
            echo "  renew <domain>                        - Renew SSL certificate"
            echo "  renew-expiring [days]                 - Renew certificates expiring within X days"
            echo "  check <domain>                        - Check certificate status"
            echo "  list                                  - List all certificates"
            echo "  delete <domain>                       - Delete SSL certificate"
            echo "  bulk                                  - Bulk generate from database"
            echo "  prerequisites                         - Check prerequisites"
            echo ""
            echo "Examples:"
            echo "  $0 generate example.com yes no"
            echo "  $0 renew example.com"
            echo "  $0 check example.com"
            echo "  $0 renew-expiring 30"
            echo "  $0 bulk"
            ;;
    esac
fi