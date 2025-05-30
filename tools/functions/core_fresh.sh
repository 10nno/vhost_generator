#!/bin/bash

# Core Fresh VHost Functions
# File: core_functions.sh
# Contains core functionality for fresh vhost management

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