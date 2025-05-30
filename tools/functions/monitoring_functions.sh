#!/bin/bash

# Monitoring & Health Check Functions
# File: monitoring_functions.sh
# Comprehensive monitoring and health checking for fresh vhosts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Monitoring configuration
MONITOR_LOG_DIR="${LOG_DIR:-$MAIN_DIR/logs}/monitoring"
HEALTH_CHECK_LOG="$MONITOR_LOG_DIR/health_check.log"
SSL_MONITOR_LOG="$MONITOR_LOG_DIR/ssl_monitor.log"
UPTIME_LOG="$MONITOR_LOG_DIR/uptime.log"
ERROR_LOG="$MONITOR_LOG_DIR/errors.log"

# VHost directory configuration
if [[ -z "$VHOST_DIR" ]]; then
    # Try to detect VHOST_DIR from common locations
    if [[ -d "$MAIN_DIR/vhost/fresh" ]]; then
        VHOST_DIR="$MAIN_DIR/vhost/fresh"
    elif [[ -d "$MAIN_DIR/vhost" ]]; then
        VHOST_DIR="$MAIN_DIR/vhost"
    elif [[ -d "/etc/nginx/vhost_generator/vhost/fresh" ]]; then
        VHOST_DIR="/etc/nginx/vhost_generator/vhost/fresh"
    elif [[ -d "/etc/nginx/vhost_generator/vhost" ]]; then
        VHOST_DIR="/etc/nginx/vhost_generator/vhost"
    else
        # Default fallback
        VHOST_DIR="$MAIN_DIR/vhost/fresh"
    fi
fi

# Initialize monitoring directories
init_monitoring() {
    # Ensure MAIN_DIR is set
    if [[ -z "$MAIN_DIR" ]]; then
        MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
    
    # Set monitoring directory
    if [[ -z "$MONITOR_LOG_DIR" ]]; then
        MONITOR_LOG_DIR="$MAIN_DIR/logs/monitoring"
    fi
    
    # Ensure VHOST_DIR is set
    if [[ -z "$VHOST_DIR" ]]; then
        # Try to detect VHOST_DIR from common locations
        if [[ -d "$MAIN_DIR/vhost/fresh" ]]; then
            VHOST_DIR="$MAIN_DIR/vhost/fresh"
        elif [[ -d "$MAIN_DIR/vhost" ]]; then
            VHOST_DIR="$MAIN_DIR/vhost"
        elif [[ -d "/etc/nginx/vhost_generator/vhost/fresh" ]]; then
            VHOST_DIR="/etc/nginx/vhost_generator/vhost/fresh"
        elif [[ -d "/etc/nginx/vhost_generator/vhost" ]]; then
            VHOST_DIR="/etc/nginx/vhost_generator/vhost"
        else
            # Default fallback
            VHOST_DIR="$MAIN_DIR/vhost/fresh"
        fi
    fi
    
    # Create directories
    [[ ! -d "$MONITOR_LOG_DIR" ]] && mkdir -p "$MONITOR_LOG_DIR"
    [[ ! -d "$VHOST_DIR" ]] && mkdir -p "$VHOST_DIR"
    
    # Update log file paths
    HEALTH_CHECK_LOG="$MONITOR_LOG_DIR/health_check.log"
    SSL_MONITOR_LOG="$MONITOR_LOG_DIR/ssl_monitor.log"
    UPTIME_LOG="$MONITOR_LOG_DIR/uptime.log"
    ERROR_LOG="$MONITOR_LOG_DIR/errors.log"
    
    # Create log files if they don't exist
    touch "$HEALTH_CHECK_LOG" "$SSL_MONITOR_LOG" "$UPTIME_LOG" "$ERROR_LOG"
}

# Function to log monitoring events
log_monitor_event() {
    local level=$1
    local component=$2
    local message=$3
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to main monitoring log
    echo "[$timestamp] [$level] [$component] $message" >> "$HEALTH_CHECK_LOG"
    
    # Log errors to separate error log
    if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
        echo "[$timestamp] [$component] $message" >> "$ERROR_LOG"
    fi
}

# Function to check single vhost health with fresh domain support
check_vhost_health() {
    local fresh_domain=$1
    local timeout=${2:-10}
    local check_ssl=${3:-"yes"}
    local test_subdomain=${4:-""}  # Optional specific subdomain to test
    
    if [[ -z "$fresh_domain" ]]; then
        echo "Usage: check_vhost_health <fresh_domain> [timeout] [check_ssl] [test_subdomain]"
        echo "Example: check_vhost_health arsku.vip 10 yes 123"
        return 1
    fi
    
    # Initialize monitoring (create directories if needed)
    init_monitoring
    
    local vhost_file="$VHOST_DIR/${fresh_domain}_fresh_vhost"
    local symlink_file="/etc/nginx/sites-enabled/${fresh_domain}_fresh_vhost"
    local status="UNKNOWN"
    local issues=()
    local warnings=()
    
    # Generate random subdomain for testing if not provided
    if [[ -z "$test_subdomain" ]]; then
        test_subdomain=$(shuf -i 100-999 -n 1)  # Random 3-digit number
    fi
    
    local test_url="$test_subdomain.$fresh_domain"
    
    echo -e "${BLUE}Health Check: $fresh_domain${NC}"
    echo "=========================="
    echo "Test URL: $test_url"
    echo "VHost file path: $vhost_file"
    echo ""
    
    # 1. Check vhost file exists with debugging
    echo -n "Checking VHost file... "
    if [[ -f "$vhost_file" ]]; then
        echo -e "${GREEN}✓${NC} VHost file exists ($vhost_file)"
    else
        echo -e "${RED}✗${NC} VHost file not found"
        echo "    Expected path: $vhost_file"
        echo "    Directory: $VHOST_DIR"
        echo "    Files in directory:"
        if [[ -d "$VHOST_DIR" ]]; then
            ls -la "$VHOST_DIR"/*fresh_vhost 2>/dev/null | head -5 || echo "    No *fresh_vhost files found"
        else
            echo "    Directory $VHOST_DIR does not exist"
        fi
        
        # Try alternative naming patterns
        local alt_patterns=(
            "$VHOST_DIR/${fresh_domain}.fresh_vhost"
            "$VHOST_DIR/${fresh_domain}-fresh_vhost" 
            "$VHOST_DIR/fresh_${fresh_domain}"
            "$VHOST_DIR/${fresh_domain}"
        )
        
        echo "    Checking alternative patterns:"
        for pattern in "${alt_patterns[@]}"; do
            if [[ -f "$pattern" ]]; then
                echo "    ✓ Found alternative: $pattern"
                vhost_file="$pattern"
                break
            else
                echo "    ✗ Not found: $pattern"
            fi
        done
        
        if [[ ! -f "$vhost_file" ]]; then
            issues+=("VHost file missing")
            status="CRITICAL"
            log_monitor_event "ERROR" "VHOST" "$fresh_domain: VHost file missing - checked $vhost_file"
        fi
    fi
    
    # 2. Check symlink status
    echo -n "Checking symlink... "
    if [[ ! -L "$symlink_file" ]]; then
        warnings+=("Symlink missing (disabled)")
        echo -e "${YELLOW}⚠${NC} Symlink missing (vhost disabled)"
        echo "    Expected: $symlink_file"
    elif [[ ! -f "$symlink_file" ]]; then
        issues+=("Broken symlink")
        status="ERROR"
        echo -e "${RED}✗${NC} Broken symlink"
        echo "    Symlink: $symlink_file"
        echo "    Points to: $(readlink "$symlink_file" 2>/dev/null || echo 'unknown')"
        log_monitor_event "ERROR" "SYMLINK" "$fresh_domain: Broken symlink"
    else
        echo -e "${GREEN}✓${NC} Symlink valid"
        echo "    Symlink: $symlink_file -> $(readlink "$symlink_file")"
    fi
    
    # 3. Check wildcard SSL certificate
    if [[ "$check_ssl" == "yes" ]]; then
        local ssl_cert_path="/etc/letsencrypt/live/$fresh_domain/fullchain.pem"
        echo -n "Checking SSL certificate... "
        if [[ -f "$ssl_cert_path" ]]; then
            # Check if certificate covers wildcard domain
            local cert_domains=$(openssl x509 -text -noout -in "$ssl_cert_path" | grep -A1 "Subject Alternative Name" | tail -1)
            
            if [[ "$cert_domains" =~ \*\.$fresh_domain ]]; then
                local expiry_date=$(openssl x509 -enddate -noout -in "$ssl_cert_path" | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_until_expiry -le 0 ]]; then
                    issues+=("SSL certificate expired")
                    status="CRITICAL"
                    echo -e "${RED}✗${NC} SSL certificate expired"
                    log_monitor_event "CRITICAL" "SSL" "$fresh_domain: SSL certificate expired"
                elif [[ $days_until_expiry -le 7 ]]; then
                    warnings+=("SSL expires in $days_until_expiry days")
                    echo -e "${YELLOW}⚠${NC} SSL expires in $days_until_expiry days"
                    log_monitor_event "WARNING" "SSL" "$fresh_domain: SSL expires in $days_until_expiry days"
                elif [[ $days_until_expiry -le 30 ]]; then
                    warnings+=("SSL expires in $days_until_expiry days")
                    echo -e "${YELLOW}⚠${NC} SSL expires in $days_until_expiry days"
                else
                    echo -e "${GREEN}✓${NC} Wildcard SSL certificate valid ($days_until_expiry days remaining)"
                fi
            else
                warnings+=("SSL certificate doesn't cover wildcard")
                echo -e "${YELLOW}⚠${NC} SSL certificate doesn't cover wildcard (*.$fresh_domain)"
            fi
        else
            warnings+=("No SSL certificate found")
            echo -e "${YELLOW}⚠${NC} No SSL certificate found"
            echo "    Expected: $ssl_cert_path"
        fi
    fi
    
    # 4. Check HTTP response on random subdomain
    echo -n "Checking HTTP response ($test_url)... "
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "http://$test_url" 2>/dev/null)
    if [[ "$http_status" =~ ^[23] ]]; then
        echo -e "${GREEN}✓${NC} HTTP $http_status"
    elif [[ "$http_status" =~ ^3 ]]; then
        echo -e "${YELLOW}⚠${NC} HTTP $http_status (redirect)"
    elif [[ -n "$http_status" ]]; then
        issues+=("HTTP error $http_status on subdomain")
        echo -e "${RED}✗${NC} HTTP $http_status"
        log_monitor_event "ERROR" "HTTP" "$fresh_domain: HTTP error $http_status on $test_url"
    else
        issues+=("No HTTP response on subdomain")
        echo -e "${RED}✗${NC} No response"
        log_monitor_event "ERROR" "HTTP" "$fresh_domain: No HTTP response on $test_url"
    fi
    
    # 5. Check HTTPS response on random subdomain (if SSL exists)
    if [[ -f "/etc/letsencrypt/live/$fresh_domain/fullchain.pem" ]]; then
        echo -n "Checking HTTPS response ($test_url)... "
        local https_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "https://$test_url" 2>/dev/null)
        if [[ "$https_status" =~ ^[23] ]]; then
            echo -e "${GREEN}✓${NC} HTTPS $https_status"
        elif [[ "$https_status" =~ ^3 ]]; then
            echo -e "${YELLOW}⚠${NC} HTTPS $https_status (redirect)"
        elif [[ -n "$https_status" ]]; then
            issues+=("HTTPS error $https_status on subdomain")
            echo -e "${RED}✗${NC} HTTPS $https_status"
            log_monitor_event "ERROR" "HTTPS" "$fresh_domain: HTTPS error $https_status on $test_url"
        else
            warnings+=("No HTTPS response on subdomain")
            echo -e "${YELLOW}⚠${NC} No HTTPS response"
        fi
    fi
    
    # 6. Check response time on random subdomain
    echo -n "Checking response time ($test_url)... "
    local response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout "$timeout" "http://$test_url" 2>/dev/null)
    if [[ -n "$response_time" ]]; then
        local response_ms=$(echo "$response_time * 1000" | bc 2>/dev/null || echo "0")
        if (( $(echo "$response_time > 5.0" | bc -l 2>/dev/null || echo 0) )); then
            warnings+=("Slow response time: ${response_ms}ms")
            echo -e "${YELLOW}⚠${NC} ${response_ms}ms (slow)"
        elif (( $(echo "$response_time > 2.0" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "${YELLOW}⚠${NC} ${response_ms}ms (acceptable)"
        else
            echo -e "${GREEN}✓${NC} ${response_ms}ms (fast)"
        fi
    else
        echo -e "${RED}✗${NC} Unable to measure"
    fi
    
    # 7. Test multiple random subdomains for consistency
    echo -n "Testing subdomain consistency... "
    local consistent_responses=0
    local total_tests=3
    
    for i in $(seq 1 $total_tests); do
        local random_sub=$(shuf -i 100-999 -n 1)
        local test_response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$random_sub.$fresh_domain" 2>/dev/null)
        if [[ "$test_response" =~ ^[23] ]]; then
            ((consistent_responses++))
        fi
    done
    
    if [[ $consistent_responses -eq $total_tests ]]; then
        echo -e "${GREEN}✓${NC} All subdomains responding ($consistent_responses/$total_tests)"
    elif [[ $consistent_responses -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC} Partial subdomain responses ($consistent_responses/$total_tests)"
        warnings+=("Inconsistent subdomain responses")
    else
        echo -e "${RED}✗${NC} No subdomain responses ($consistent_responses/$total_tests)"
        issues+=("All subdomain tests failed")
    fi
    
    # 8. Check if main domain proxy is working (extract from vhost config)
    if [[ -f "$vhost_file" ]]; then
        local main_domain=$(grep -o 'proxy_pass http://[^/]*' "$vhost_file" | sed 's/proxy_pass http:\/\///' | head -1 2>/dev/null)
        if [[ -n "$main_domain" ]]; then
            echo -n "Checking main domain proxy ($main_domain)... "
            local main_status=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$timeout" "http://$main_domain" 2>/dev/null)
            if [[ "$main_status" =~ ^[23] ]]; then
                echo -e "${GREEN}✓${NC} Main domain accessible (HTTP $main_status)"
            elif [[ "$main_status" =~ ^3 ]]; then
                echo -e "${YELLOW}⚠${NC} Main domain redirect (HTTP $main_status)"
            elif [[ -n "$main_status" ]]; then
                warnings+=("Main domain issue: HTTP $main_status")
                echo -e "${YELLOW}⚠${NC} Main domain issue (HTTP $main_status)"
            else
                warnings+=("Main domain unreachable")
                echo -e "${YELLOW}⚠${NC} Main domain unreachable"
            fi
        fi
    fi
    
    # Determine overall status
    if [[ ${#issues[@]} -eq 0 ]]; then
        if [[ ${#warnings[@]} -eq 0 ]]; then
            status="HEALTHY"
        else
            status="WARNING"
        fi
    elif [[ "$status" != "CRITICAL" ]]; then
        status="ERROR"
    fi
    
    # Summary
    echo ""
    echo "Summary:"
    echo "--------"
    echo "Tested subdomain: $test_url"
    case $status in
        "HEALTHY")
            echo -e "Status: ${GREEN}$status${NC}"
            log_monitor_event "INFO" "HEALTH" "$fresh_domain: Healthy (tested: $test_url)"
            ;;
        "WARNING")
            echo -e "Status: ${YELLOW}$status${NC}"
            log_monitor_event "WARNING" "HEALTH" "$fresh_domain: Has warnings (tested: $test_url)"
            ;;
        "ERROR")
            echo -e "Status: ${RED}$status${NC}"
            log_monitor_event "ERROR" "HEALTH" "$fresh_domain: Has errors (tested: $test_url)"
            ;;
        "CRITICAL")
            echo -e "Status: ${RED}$status${NC}"
            log_monitor_event "CRITICAL" "HEALTH" "$fresh_domain: Critical issues (tested: $test_url)"
            ;;
    esac
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "Issues:"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}✗${NC} $issue"
        done
    fi
    
    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "Warnings:"
        for warning in "${warnings[@]}"; do
            echo -e "  ${YELLOW}⚠${NC} $warning"
        done
    fi
    
    # Return status code
    case $status in
        "HEALTHY") return 0 ;;
        "WARNING") return 1 ;;
        "ERROR") return 2 ;;
        "CRITICAL") return 3 ;;
        *) return 4 ;;
    esac
}

# Function to check all vhosts health
check_all_vhosts_health() {
    local timeout=${1:-10}
    local check_ssl=${2:-"yes"}
    local output_format=${3:-"summary"}  # summary, detailed, json
    
    init_monitoring
    
    echo -e "${BLUE}Fresh VHosts Health Check${NC}"
    echo "========================="
    echo "Started: $(date)"
    echo ""
    
    if [[ ! -d "$VHOST_DIR" ]]; then
        echo -e "${RED}✗ VHost directory not found: $VHOST_DIR${NC}"
        return 1
    fi
    
    local total_count=0
    local healthy_count=0
    local warning_count=0
    local error_count=0
    local critical_count=0
    
    local healthy_domains=()
    local warning_domains=()
    local error_domains=()
    local critical_domains=()
    
    # Process each vhost
    for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
        if [[ -f "$vhost_file" ]]; then
            local filename=$(basename "$vhost_file")
            local domain="${filename%_fresh_vhost}"  # This will correctly extract "arsku.vip" from "arsku.vip_fresh_vhost"
            
            ((total_count++))
            
            if [[ "$output_format" == "detailed" ]]; then
                echo ""
                check_vhost_health "$domain" "$timeout" "$check_ssl"
                local result=$?
            else
                echo -n "Checking $domain... "
                check_vhost_health "$domain" "$timeout" "$check_ssl" >/dev/null 2>&1
                local result=$?
            fi
            
            case $result in
                0)
                    ((healthy_count++))
                    healthy_domains+=("$domain")
                    [[ "$output_format" != "detailed" ]] && echo -e "${GREEN}HEALTHY${NC}"
                    ;;
                1)
                    ((warning_count++))
                    warning_domains+=("$domain")
                    [[ "$output_format" != "detailed" ]] && echo -e "${YELLOW}WARNING${NC}"
                    ;;
                2)
                    ((error_count++))
                    error_domains+=("$domain")
                    [[ "$output_format" != "detailed" ]] && echo -e "${RED}ERROR${NC}"
                    ;;
                3)
                    ((critical_count++))
                    critical_domains+=("$domain")
                    [[ "$output_format" != "detailed" ]] && echo -e "${RED}CRITICAL${NC}"
                    ;;
                *)
                    ((error_count++))
                    error_domains+=("$domain")
                    [[ "$output_format" != "detailed" ]] && echo -e "${RED}UNKNOWN${NC}"
                    ;;
            esac
        fi
    done
    
    # Overall summary
    echo ""
    echo "Health Check Summary"
    echo "==================="
    echo "Completed: $(date)"
    echo "Total VHosts: $total_count"
    echo -e "${GREEN}Healthy: $healthy_count${NC}"
    echo -e "${YELLOW}Warnings: $warning_count${NC}"
    echo -e "${RED}Errors: $error_count${NC}"
    echo -e "${RED}Critical: $critical_count${NC}"
    
    # Detailed breakdown
    if [[ ${#critical_domains[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Critical Issues:${NC}"
        for domain in "${critical_domains[@]}"; do
            echo "  • $domain"
        done
    fi
    
    if [[ ${#error_domains[@]} -gt 0 ]]; then
        echo ""
        echo -e "${RED}Errors:${NC}"
        for domain in "${error_domains[@]}"; do
            echo "  • $domain"
        done
    fi
    
    if [[ ${#warning_domains[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Warnings:${NC}"
        for domain in "${warning_domains[@]}"; do
            echo "  • $domain"
        done
    fi
    
    # JSON output
    if [[ "$output_format" == "json" ]]; then
        echo ""
        echo "JSON Report:"
        echo "============"
        cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "summary": {
    "total": $total_count,
    "healthy": $healthy_count,
    "warnings": $warning_count,
    "errors": $error_count,
    "critical": $critical_count
  },
  "domains": {
    "healthy": [$(printf '"%s",' "${healthy_domains[@]}" | sed 's/,$//')],
    "warnings": [$(printf '"%s",' "${warning_domains[@]}" | sed 's/,$//')],
    "errors": [$(printf '"%s",' "${error_domains[@]}" | sed 's/,$//')],
    "critical": [$(printf '"%s",' "${critical_domains[@]}" | sed 's/,$//')]
  }
}
EOF
    fi
    
    # Log summary
    log_monitor_event "INFO" "SUMMARY" "Health check completed: $total_count total, $healthy_count healthy, $warning_count warnings, $error_count errors, $critical_count critical"
    
    # Return overall status
    if [[ $critical_count -gt 0 ]]; then
        return 3
    elif [[ $error_count -gt 0 ]]; then
        return 2
    elif [[ $warning_count -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Function to monitor SSL certificate expiry
ssl_expiry_monitor() {
    local warning_days=${1:-30}
    local critical_days=${2:-7}
    local output_format=${3:-"summary"}
    
    init_monitoring
    
    echo -e "${BLUE}SSL Certificate Expiry Monitor${NC}"
    echo "=============================="
    echo "Warning threshold: $warning_days days"
    echo "Critical threshold: $critical_days days"
    echo ""
    
    local total_certs=0
    local valid_certs=0
    local warning_certs=0
    local critical_certs=0
    local expired_certs=0
    
    local warning_domains=()
    local critical_domains=()
    local expired_domains=()
    
    # Check all domains with SSL certificates
    if [[ -d "/etc/letsencrypt/live" ]]; then
        for cert_dir in "/etc/letsencrypt/live"/*; do
            if [[ -d "$cert_dir" ]]; then
                local domain=$(basename "$cert_dir")
                local cert_file="$cert_dir/fullchain.pem"
                
                if [[ -f "$cert_file" ]]; then
                    ((total_certs++))
                    
                    local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
                    local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                    local current_timestamp=$(date +%s)
                    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                    
                    if [[ $days_until_expiry -le 0 ]]; then
                        ((expired_certs++))
                        expired_domains+=("$domain")
                        echo -e "${RED}✗ $domain - EXPIRED${NC} ($expiry_date)"
                        log_monitor_event "CRITICAL" "SSL" "$domain: Certificate expired"
                    elif [[ $days_until_expiry -le $critical_days ]]; then
                        ((critical_certs++))
                        critical_domains+=("$domain")
                        echo -e "${RED}! $domain - CRITICAL${NC} (expires in $days_until_expiry days)"
                        log_monitor_event "CRITICAL" "SSL" "$domain: Certificate expires in $days_until_expiry days"
                    elif [[ $days_until_expiry -le $warning_days ]]; then
                        ((warning_certs++))
                        warning_domains+=("$domain")
                        echo -e "${YELLOW}⚠ $domain - WARNING${NC} (expires in $days_until_expiry days)"
                        log_monitor_event "WARNING" "SSL" "$domain: Certificate expires in $days_until_expiry days"
                    else
                        ((valid_certs++))
                        if [[ "$output_format" == "detailed" ]]; then
                            echo -e "${GREEN}✓ $domain - VALID${NC} (expires in $days_until_expiry days)"
                        fi
                    fi
                fi
            fi
        done
    fi
    
    echo ""
    echo "SSL Expiry Summary"
    echo "=================="
    echo "Total certificates: $total_certs"
    echo -e "${GREEN}Valid: $valid_certs${NC}"
    echo -e "${YELLOW}Warning: $warning_certs${NC}"
    echo -e "${RED}Critical: $critical_certs${NC}"
    echo -e "${RED}Expired: $expired_certs${NC}"
    
    # Show action items
    if [[ $expired_certs -gt 0 || $critical_certs -gt 0 || $warning_certs -gt 0 ]]; then
        echo ""
        echo "Action Required:"
        echo "==============="
        
        if [[ ${#expired_domains[@]} -gt 0 ]]; then
            echo -e "${RED}Expired certificates (renew immediately):${NC}"
            for domain in "${expired_domains[@]}"; do
                echo "  ./add_fresh_vhost.sh ssl-renew $domain"
            done
        fi
        
        if [[ ${#critical_domains[@]} -gt 0 ]]; then
            echo -e "${RED}Critical expiry (renew within $critical_days days):${NC}"
            for domain in "${critical_domains[@]}"; do
                echo "  ./add_fresh_vhost.sh ssl-renew $domain"
            done
        fi
        
        if [[ ${#warning_domains[@]} -gt 0 ]]; then
            echo -e "${YELLOW}Warning expiry (renew within $warning_days days):${NC}"
            for domain in "${warning_domains[@]}"; do
                echo "  ./add_fresh_vhost.sh ssl-renew $domain"
            done
        fi
    fi
    
    # Log summary
    log_monitor_event "INFO" "SSL" "SSL check completed: $total_certs total, $expired_certs expired, $critical_certs critical, $warning_certs warning"
    
    # Return status
    if [[ $expired_certs -gt 0 ]]; then
        return 3
    elif [[ $critical_certs -gt 0 ]]; then
        return 2
    elif [[ $warning_certs -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Function to check nginx status and configuration
nginx_health_check() {
    echo -e "${BLUE}Nginx Health Check${NC}"
    echo "=================="
    
    local issues=0
    
    # Check if nginx is running
    echo -n "Nginx service status... "
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
        ((issues++))
        log_monitor_event "CRITICAL" "NGINX" "Nginx service not running"
    fi
    
    # Check if nginx is enabled
    echo -n "Nginx auto-start... "
    if systemctl is-enabled --quiet nginx; then
        echo -e "${GREEN}✓ Enabled${NC}"
    else
        echo -e "${YELLOW}⚠ Not enabled${NC}"
        log_monitor_event "WARNING" "NGINX" "Nginx not enabled for auto-start"
    fi
    
    # Test nginx configuration
    echo -n "Configuration syntax... "
    if nginx -t 2>/dev/null; then
        echo -e "${GREEN}✓ Valid${NC}"
    else
        echo -e "${RED}✗ Invalid${NC}"
        ((issues++))
        log_monitor_event "ERROR" "NGINX" "Nginx configuration syntax errors"
    fi
    
    # Check nginx error log for recent errors
    echo -n "Recent errors... "
    if [[ -f "/var/log/nginx/error.log" ]]; then
        local recent_errors=$(tail -100 /var/log/nginx/error.log | grep "$(date +%Y/%m/%d)" | wc -l)
        if [[ $recent_errors -gt 0 ]]; then
            echo -e "${YELLOW}⚠ $recent_errors today${NC}"
            log_monitor_event "WARNING" "NGINX" "$recent_errors errors found in today's logs"
        else
            echo -e "${GREEN}✓ None today${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Log file not found${NC}"
    fi
    
    # Check disk space for logs
    echo -n "Log disk space... "
    if [[ -d "/var/log/nginx" ]]; then
        local log_size=$(du -sh /var/log/nginx 2>/dev/null | cut -f1)
        echo -e "${GREEN}✓ $log_size used${NC}"
    else
        echo -e "${YELLOW}⚠ Log directory not found${NC}"
    fi
    
    echo ""
    if [[ $issues -eq 0 ]]; then
        echo -e "Overall Status: ${GREEN}HEALTHY${NC}"
        return 0
    else
        echo -e "Overall Status: ${RED}ISSUES FOUND${NC}"
        return 1
    fi
}

# Function for continuous monitoring
continuous_monitor() {
    local interval=${1:-300}  # 5 minutes default
    local max_runs=${2:-0}    # 0 = infinite
    
    echo -e "${BLUE}Continuous Monitoring Started${NC}"
    echo "============================="
    echo "Interval: ${interval}s"
    echo "Max runs: ${max_runs:-infinite}"
    echo "Started: $(date)"
    echo ""
    echo "Press Ctrl+C to stop"
    echo ""
    
    local run_count=0
    
    while true; do
        ((run_count++))
        
        echo -e "${CYAN}[Run $run_count] $(date)${NC}"
        echo "----------------------------------------"
        
        # Quick health check
        check_all_vhosts_health 5 "yes" "summary"
        local health_status=$?
        
        # Log the run
        log_monitor_event "INFO" "MONITOR" "Continuous monitoring run $run_count completed with status $health_status"
        
        # Check if we should stop
        if [[ $max_runs -gt 0 && $run_count -ge $max_runs ]]; then
            echo ""
            echo -e "${BLUE}Maximum runs reached. Stopping monitoring.${NC}"
            break
        fi
        
        echo ""
        echo "Next check in ${interval}s..."
        echo ""
        
        sleep "$interval"
    done
}

# Function to check uptime and response times
uptime_monitor() {
    local domains_list=${1:-""}
    local log_results=${2:-"yes"}
    
    init_monitoring
    
    echo -e "${BLUE}Uptime & Response Time Monitor${NC}"
    echo "=============================="
    echo "Started: $(date)"
    echo ""
    
    # If no specific domains provided, check all
    if [[ -z "$domains_list" ]]; then
        if [[ ! -d "$VHOST_DIR" ]]; then
            echo "No vhost directory found"
            return 1
        fi
        
        for vhost_file in "$VHOST_DIR"/*_fresh_vhost; do
            if [[ -f "$vhost_file" ]]; then
                local filename=$(basename "$vhost_file")
                local domain="${filename%_fresh_vhost}"  # Extracts "arsku.vip" from "arsku.vip_fresh_vhost"
                check_domain_uptime "$domain" "$log_results"
            fi
        done
    else
        # Check specific domains
        IFS=',' read -ra DOMAINS <<< "$domains_list"
        for domain in "${DOMAINS[@]}"; do
            domain=$(echo "$domain" | xargs)  # Trim whitespace
            check_domain_uptime "$domain" "$log_results"
        done
    fi
}

# Helper function to check single domain uptime with fresh domain support
check_domain_uptime() {
    local domain=$1
    local log_results=${2:-"yes"}
    local test_subdomain=${3:-""}
    
    # Generate random subdomain for fresh domain testing
    if [[ -z "$test_subdomain" ]]; then
        test_subdomain=$(shuf -i 100-999 -n 1)
    fi
    
    local test_url="$test_subdomain.$domain"
    echo -n "Checking $domain ($test_url)... "
    
    local start_time=$(date +%s.%N)
    
    # Test both HTTP and HTTPS
    local http_status=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}:%{time_connect}" --connect-timeout 10 "http://$test_url" 2>/dev/null)
    local https_status=""
    
    # Check if SSL exists for HTTPS test
    if [[ -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]]; then
        https_status=$(curl -s -o /dev/null -w "%{http_code}:%{time_total}:%{time_connect}" --connect-timeout 10 "https://$test_url" 2>/dev/null)
    fi
    
    local end_time=$(date +%s.%N)
    
    # Process HTTP results
    if [[ -n "$http_status" ]]; then
        IFS=':' read -ra HTTP_RESPONSE <<< "$http_status"
        local http_code="${HTTP_RESPONSE[0]}"
        local http_time="${HTTP_RESPONSE[1]}"
        local http_connect="${HTTP_RESPONSE[2]}"
        
        local http_ms=$(echo "$http_time * 1000" | bc 2>/dev/null || echo "0")
        
        # Process HTTPS results if available
        local https_info=""
        if [[ -n "$https_status" ]]; then
            IFS=':' read -ra HTTPS_RESPONSE <<< "$https_status"
            local https_code="${HTTPS_RESPONSE[0]}"
            local https_time="${HTTPS_RESPONSE[1]}"
            local https_ms=$(echo "$https_time * 1000" | bc 2>/dev/null || echo "0")
            https_info=" | HTTPS: $https_code (${https_ms}ms)"
        fi
        
        if [[ "$http_code" =~ ^[23] ]]; then
            echo -e "${GREEN}UP${NC} (HTTP: $http_code ${http_ms}ms$https_info)"
            [[ "$log_results" == "yes" ]] && log_monitor_event "INFO" "UPTIME" "$domain: UP - HTTP $http_code (${http_ms}ms) - Tested: $test_url"
        else
            echo -e "${RED}DOWN${NC} (HTTP: $http_code$https_info)"
            [[ "$log_results" == "yes" ]] && log_monitor_event "ERROR" "UPTIME" "$domain: DOWN - HTTP $http_code - Tested: $test_url"
        fi
    else
        echo -e "${RED}DOWN${NC} (No response from $test_url)"
        [[ "$log_results" == "yes" ]] && log_monitor_event "ERROR" "UPTIME" "$domain: DOWN - No response from $test_url"
    fi
}

# Function to analyze error patterns
analyze_error_patterns() {
    local days=${1:-7}
    local min_occurrences=${2:-3}
    
    init_monitoring
    
    echo -e "${BLUE}Error Pattern Analysis${NC}"
    echo "======================"
    echo "Analyzing last $days days"
    echo "Minimum occurrences: $min_occurrences"
    echo ""
    
    if [[ ! -f "$ERROR_LOG" ]]; then
        echo "No error log found: $ERROR_LOG"
        return 1
    fi
    
    # Get date range
    local start_date=$(date -d "$days days ago" "+%Y-%m-%d")
    
    echo "Common Error Patterns:"
    echo "======================"
    
    # Analyze common errors
    grep "^\[$start_date" "$ERROR_LOG" | \
    awk -F'] ' '{print $3}' | \
    sort | uniq -c | sort -nr | \
    while read count error; do
        if [[ $count -ge $min_occurrences ]]; then
            echo -e "${RED}$count occurrences:${NC} $error"
        fi
    done
    
    echo ""
    echo "Error Timeline (last 24 hours):"
    echo "==============================="
    
    # Show hourly error counts for last 24 hours
    for hour in {23..0}; do
        local check_time=$(date -d "$hour hours ago" "+%Y-%m-%d %H")
        local error_count=$(grep "^\[$check_time" "$ERROR_LOG" 2>/dev/null | wc -l)
        
        if [[ $error_count -gt 0 ]]; then
            local bar=""
            for ((i=0; i<error_count && i<50; i++)); do
                bar+="█"
            done
            printf "%s:00 [%2d] %s\n" "$check_time" "$error_count" "$bar"
        fi
    done
}

# Function to generate health report
generate_health_report() {
    local output_file=${1:-"$MONITOR_LOG_DIR/health_report_$(date +%Y%m%d_%H%M%S).html"}
    local include_logs=${2:-"no"}
    
    init_monitoring
    
    echo "Generating health report..."
    echo "Output: $output_file"
    
    # Create HTML report
    cat > "$output_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Fresh VHost Health Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f4f4f4; padding: 20px; border-radius: 5px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .stat { background: #fff; border: 1px solid #ddd; padding: 15px; border-radius: 5px; flex: 1; text-align: center; }
        .healthy { border-left: 5px solid #28a745; }
        .warning { border-left: 5px solid #ffc107; }
        .error { border-left: 5px solid #dc3545; }
        .critical { border-left: 5px solid #6f42c1; }
        .logs { background: #f8f9fa; padding: 15px; border-radius: 5px; font-family: monospace; font-size: 12px; }
    </style>
</head>
<body>
EOF
    
    # Add report header
    cat >> "$output_file" << EOF
    <div class="header">
        <h1>Fresh VHost Health Report</h1>
        <p><strong>Generated:</strong> $(date)</p>
        <p><strong>Server:</strong> $(hostname)</p>
    </div>
EOF
    
    # Generate health data
    local temp_file="/tmp/health_check_$.json"
    check_all_vhosts_health 10 "yes" "json" > "$temp_file" 2>/dev/null
    
    # Extract summary data (simplified for demo)
    local total=$(grep -o '"total": [0-9]*' "$temp_file" | cut -d: -f2 | tr -d ' ' || echo "0")
    local healthy=$(grep -o '"healthy": [0-9]*' "$temp_file" | cut -d: -f2 | tr -d ' ' || echo "0")
    local warnings=$(grep -o '"warnings": [0-9]*' "$temp_file" | cut -d: -f2 | tr -d ' ' || echo "0")
    local errors=$(grep -o '"errors": [0-9]*' "$temp_file" | cut -d: -f2 | tr -d ' ' || echo "0")
    local critical=$(grep -o '"critical": [0-9]*' "$temp_file" | cut -d: -f2 | tr -d ' ' || echo "0")
    
    # Add summary section
    cat >> "$output_file" << EOF
    <div class="summary">
        <div class="stat healthy">
            <h3>$healthy</h3>
            <p>Healthy</p>
        </div>
        <div class="stat warning">
            <h3>$warnings</h3>
            <p>Warnings</p>
        </div>
        <div class="stat error">
            <h3>$errors</h3>
            <p>Errors</p>
        </div>
        <div class="stat critical">
            <h3>$critical</h3>
            <p>Critical</p>
        </div>
    </div>
    
    <h2>System Status</h2>
EOF
    
    # Add nginx status
    nginx_health_check >> "$temp_file.nginx" 2>&1
    cat >> "$output_file" << EOF
    <h3>Nginx Status</h3>
    <div class="logs">
$(cat "$temp_file.nginx" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
    </div>
EOF
    
    # Add SSL status
    ssl_expiry_monitor 30 7 "summary" >> "$temp_file.ssl" 2>&1
    cat >> "$output_file" << EOF
    <h3>SSL Certificate Status</h3>
    <div class="logs">
$(cat "$temp_file.ssl" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
    </div>
EOF
    
    # Add recent logs if requested
    if [[ "$include_logs" == "yes" && -f "$HEALTH_CHECK_LOG" ]]; then
        cat >> "$output_file" << EOF
    <h2>Recent Monitoring Logs</h2>
    <div class="logs">
$(tail -50 "$HEALTH_CHECK_LOG" | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g')
    </div>
EOF
    fi
    
    # Close HTML
    cat >> "$output_file" << 'EOF'
    
    <div class="header" style="margin-top: 30px;">
        <p><em>Report generated by Fresh VHost Management System</em></p>
    </div>
</body>
</html>
EOF
    
    # Cleanup temp files
    rm -f "$temp_file" "$temp_file.nginx" "$temp_file.ssl"
    
    echo "✓ Health report generated: $output_file"
    return 0
}

# Interactive monitoring menu
interactive_monitoring_menu() {
    while true; do
        echo ""
        echo -e "${BLUE}Fresh VHost Monitoring & Health Checks${NC}"
        echo "======================================"
        echo "1. Check single domain health"
        echo "2. Check all domains health"
        echo "3. SSL certificate monitor"
        echo "4. Nginx health check"
        echo "5. Uptime monitor"
        echo "6. Continuous monitoring"
        echo "7. Generate health report"
        echo "8. Analyze error patterns"
        echo "9. View monitoring logs"
        echo "10. Back to main menu"
        echo ""
        
        read -p "Choose option (1-10): " choice
        
        case $choice in
            1)
                echo ""
                read -p "Enter domain name: " domain
                if [[ -n "$domain" ]]; then
                    read -p "Specific subdomain to test (or Enter for random): " subdomain
                    check_vhost_health "$domain" 10 "yes" "$subdomain"
                fi
                ;;
            2)
                echo ""
                echo "Output format:"
                echo "1. Summary (default)"
                echo "2. Detailed"
                echo "3. JSON"
                read -p "Choose format (1-3): " format_choice
                
                case $format_choice in
                    2) format="detailed" ;;
                    3) format="json" ;;
                    *) format="summary" ;;
                esac
                
                check_all_vhosts_health 10 "yes" "$format"
                ;;
            3)
                echo ""
                read -p "Warning days threshold [30]: " warn_days
                read -p "Critical days threshold [7]: " crit_days
                warn_days=${warn_days:-30}
                crit_days=${crit_days:-7}
                
                ssl_expiry_monitor "$warn_days" "$crit_days" "detailed"
                ;;
            4)
                echo ""
                nginx_health_check
                ;;
            5)
                echo ""
                read -p "Specific domains (comma-separated) or Enter for all: " domains
                uptime_monitor "$domains"
                ;;
            6)
                echo ""
                read -p "Check interval in seconds [300]: " interval
                read -p "Maximum runs (0 for infinite) [0]: " max_runs
                interval=${interval:-300}
                max_runs=${max_runs:-0}
                
                continuous_monitor "$interval" "$max_runs"
                ;;
            7)
                echo ""
                read -p "Output file path [auto]: " output_file
                read -p "Include recent logs? (y/n) [n]: " include_logs
                include_logs=${include_logs:-n}
                
                if [[ -z "$output_file" ]]; then
                    generate_health_report "" "$include_logs"
                else
                    generate_health_report "$output_file" "$include_logs"
                fi
                ;;
            8)
                echo ""
                read -p "Days to analyze [7]: " days
                read -p "Minimum occurrences [3]: " min_occur
                days=${days:-7}
                min_occur=${min_occur:-3}
                
                analyze_error_patterns "$days" "$min_occur"
                ;;
            9)
                echo ""
                echo "Monitoring Logs"
                echo "==============="
                echo "1. Health check log"
                echo "2. SSL monitor log"
                echo "3. Error log"
                echo "4. Uptime log"
                read -p "Choose log (1-4): " log_choice
                
                case $log_choice in
                    1) [[ -f "$HEALTH_CHECK_LOG" ]] && tail -50 "$HEALTH_CHECK_LOG" || echo "No health check log found" ;;
                    2) [[ -f "$SSL_MONITOR_LOG" ]] && tail -50 "$SSL_MONITOR_LOG" || echo "No SSL monitor log found" ;;
                    3) [[ -f "$ERROR_LOG" ]] && tail -50 "$ERROR_LOG" || echo "No error log found" ;;
                    4) [[ -f "$UPTIME_LOG" ]] && tail -50 "$UPTIME_LOG" || echo "No uptime log found" ;;
                    *) echo "Invalid option" ;;
                esac
                ;;
            10)
                return 0
                ;;
            *)
                echo "Invalid option. Please choose 1-10."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}