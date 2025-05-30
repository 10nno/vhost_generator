#!/bin/bash

# Enhanced Domain Database File
# File: domains_db.sh
# This file contains the domain database using associative arrays
# Enhanced to support multiple domains per category and reads from external data file

# Declare associative arrays for domain data
declare -A MAIN_DOMAINS
declare -A KAWAL_DOMAINS  
declare -A FRESH_DOMAINS

# Get the database directory path
DATABASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_DATA_FILE="$DATABASE_DIR/domain_data.txt"

# Function to load domain data from text file
load_domain_data_from_file() {
    if [[ ! -f "$DOMAIN_DATA_FILE" ]]; then
        echo "Warning: Domain data file not found at: $DOMAIN_DATA_FILE"
        echo "Creating empty domain data file..."
        cat << 'EOF' > "$DOMAIN_DATA_FILE"
# Domain Data File
# Format: BRAND|MAIN_DOMAINS|KAWAL_DOMAINS|FRESH_DOMAINS
# Multiple domains per category are separated by commas
# Lines starting with # are comments and will be ignored

EOF
        return 1
    fi
    
    local loaded_count=0
    
    # Clear existing arrays
    MAIN_DOMAINS=()
    KAWAL_DOMAINS=()
    FRESH_DOMAINS=()
    
    # Read file with proper handling of last line without newline
    while IFS='|' read -r brand main_domains kawal_domains fresh_domains || [[ -n "$brand" ]]; do
        # Skip comment lines and empty lines
        [[ "$brand" =~ ^#.*$ ]] && continue
        [[ -z "$brand" ]] && continue
        
        # Convert brand to uppercase and trim whitespace
        brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]' | xargs)
        main_domains=$(echo "$main_domains" | xargs)
        kawal_domains=$(echo "$kawal_domains" | xargs)
        fresh_domains=$(echo "$fresh_domains" | xargs)
        
        # Load into associative arrays
        MAIN_DOMAINS[$brand]="$main_domains"
        KAWAL_DOMAINS[$brand]="$kawal_domains"
        FRESH_DOMAINS[$brand]="$fresh_domains"
        
        ((loaded_count++))
    done < "$DOMAIN_DATA_FILE"
    
    return 0
}

# Function to save domain data to text file
save_domain_data_to_file() {
    local temp_file="${DOMAIN_DATA_FILE}.tmp"
    
    # Create backup of original file
    if [[ -f "$DOMAIN_DATA_FILE" ]]; then
        cp "$DOMAIN_DATA_FILE" "${DOMAIN_DATA_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Write header
    cat << 'EOF' > "$temp_file"
# Domain Data File
# Format: BRAND|MAIN_DOMAINS|KAWAL_DOMAINS|FRESH_DOMAINS
# Multiple domains per category are separated by commas
# Lines starting with # are comments and will be ignored

EOF
    
    # Write domain data
    for brand in $(get_all_brands); do
        local main_domains="${MAIN_DOMAINS[$brand]}"
        local kawal_domains="${KAWAL_DOMAINS[$brand]}"
        local fresh_domains="${FRESH_DOMAINS[$brand]}"
        
        echo "$brand|$main_domains|$kawal_domains|$fresh_domains" >> "$temp_file"
    done
    
    # Replace original file with updated version
    mv "$temp_file" "$DOMAIN_DATA_FILE"
    
    return 0
}

# Function to initialize domain database
init_domain_database() {
    load_domain_data_from_file
    local loaded_count=$(get_brand_count)
    
    if [[ $loaded_count -eq 0 ]]; then
        echo "No domain data loaded. Please add domains using the domain manager."
    else
        echo "Domain database initialized with $loaded_count brands from: $DOMAIN_DATA_FILE"
    fi
}

# Function to add new brand to database
add_brand_to_db() {
    local brand=$1
    local main_domains=$2
    local kawal_domains=$3
    local fresh_domains=$4
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Add to associative arrays
    MAIN_DOMAINS[$brand]="$main_domains"
    KAWAL_DOMAINS[$brand]="$kawal_domains"
    FRESH_DOMAINS[$brand]="$fresh_domains"
    
    # Save to file
    save_domain_data_to_file
}

# Function to update existing brand in database
update_brand_in_db() {
    local brand=$1
    local main_domains=$2
    local kawal_domains=$3
    local fresh_domains=$4
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Update in associative arrays
    MAIN_DOMAINS[$brand]="$main_domains"
    KAWAL_DOMAINS[$brand]="$kawal_domains"
    FRESH_DOMAINS[$brand]="$fresh_domains"
    
    # Save to file
    save_domain_data_to_file
}

# Function to delete brand from database
delete_brand_from_db() {
    local brand=$1
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    # Remove from all associative arrays
    unset MAIN_DOMAINS[$brand]
    unset KAWAL_DOMAINS[$brand]
    unset FRESH_DOMAINS[$brand]
    
    # Save to file
    save_domain_data_to_file
}

# Function to check if brand exists
brand_exists() {
    local brand=$1
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    [[ -n "${MAIN_DOMAINS[$brand]}" ]]
}

# Function to get all brand names
get_all_brands() {
    printf '%s\n' "${!MAIN_DOMAINS[@]}" | sort
}

# Function to get brand count
get_brand_count() {
    echo "${#MAIN_DOMAINS[@]}"
}

# Function to get domains for a brand by category
get_brand_domains() {
    local brand=$1
    local category=$2
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    case $category in
        "main")
            if [[ -n "${MAIN_DOMAINS[$brand]}" ]]; then
                echo "${MAIN_DOMAINS[$brand]}"
                return 0
            fi
            ;;
        "kawal")
            if [[ -n "${KAWAL_DOMAINS[$brand]}" ]]; then
                echo "${KAWAL_DOMAINS[$brand]}"
                return 0
            fi
            ;;
        "fresh")
            if [[ -n "${FRESH_DOMAINS[$brand]}" ]]; then
                echo "${FRESH_DOMAINS[$brand]}"
                return 0
            fi
            ;;
        "all")
            if brand_exists "$brand"; then
                echo "main:${MAIN_DOMAINS[$brand]}|kawal:${KAWAL_DOMAINS[$brand]}|fresh:${FRESH_DOMAINS[$brand]}"
                return 0
            fi
            ;;
        *)
            echo "Invalid category. Use: main, kawal, fresh, or all"
            return 1
            ;;
    esac
    
    return 1
}

# Function to get domain count for a brand and category
get_domain_count() {
    local brand=$1
    local category=$2
    
    local domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -eq 0 && -n "$domains" ]]; then
        IFS=',' read -ra domain_array <<< "$domains"
        echo "${#domain_array[@]}"
    else
        echo "0"
    fi
}

# Function to get specific domain by index from a category
get_domain_by_index() {
    local brand=$1
    local category=$2
    local index=$3
    
    local domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -eq 0 && -n "$domains" ]]; then
        IFS=',' read -ra domain_array <<< "$domains"
        if [[ $index -ge 0 && $index -lt ${#domain_array[@]} ]]; then
            echo "${domain_array[$index]}"
            return 0
        else
            echo "Index $index out of range (0-$((${#domain_array[@]}-1)))"
            return 1
        fi
    else
        echo "No domains found for brand $brand in category $category"
        return 1
    fi
}

# Function to add domain to existing brand category
add_domain_to_category() {
    local brand=$1
    local category=$2
    local new_domain=$3
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found"
        return 1
    fi
    
    local current_domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -eq 0 ]]; then
        # Check if domain already exists
        if [[ "$current_domains" == *"$new_domain"* ]]; then
            echo "Domain '$new_domain' already exists in $category category for brand $brand"
            return 1
        fi
        
        # Add new domain
        local updated_domains="$current_domains,$new_domain"
    else
        # First domain in this category
        local updated_domains="$new_domain"
    fi
    
    # Update the appropriate array
    case $category in
        "main") MAIN_DOMAINS[$brand]="$updated_domains" ;;
        "kawal") KAWAL_DOMAINS[$brand]="$updated_domains" ;;
        "fresh") FRESH_DOMAINS[$brand]="$updated_domains" ;;
        *) 
            echo "Invalid category. Use: main, kawal, or fresh"
            return 1
            ;;
    esac
    
    # Save to file
    save_domain_data_to_file
    
    echo "Added '$new_domain' to $category category for brand $brand"
    echo "✓ Changes saved to: $DOMAIN_DATA_FILE"
    return 0
}

# Function to remove domain from brand category
remove_domain_from_category() {
    local brand=$1
    local category=$2
    local domain_to_remove=$3
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        echo "Brand '$brand' not found"
        return 1
    fi
    
    local current_domains=$(get_brand_domains "$brand" "$category")
    if [[ $? -eq 0 ]]; then
        # Convert to array and rebuild without the target domain
        IFS=',' read -ra domain_array <<< "$current_domains"
        local new_domains=""
        local found=false
        
        for domain in "${domain_array[@]}"; do
            if [[ "$domain" != "$domain_to_remove" ]]; then
                if [[ -n "$new_domains" ]]; then
                    new_domains="$new_domains,$domain"
                else
                    new_domains="$domain"
                fi
            else
                found=true
            fi
        done
        
        if [[ "$found" == false ]]; then
            echo "Domain '$domain_to_remove' not found in $category category for brand $brand"
            return 1
        fi
        
        # Update the appropriate array
        case $category in
            "main") MAIN_DOMAINS[$brand]="$new_domains" ;;
            "kawal") KAWAL_DOMAINS[$brand]="$new_domains" ;;
            "fresh") FRESH_DOMAINS[$brand]="$new_domains" ;;
            *) 
                echo "Invalid category. Use: main, kawal, or fresh"
                return 1
                ;;
        esac
        
        # Save to file
        save_domain_data_to_file
        
        echo "Removed '$domain_to_remove' from $category category for brand $brand"
        echo "✓ Changes saved to: $DOMAIN_DATA_FILE"
        return 0
    else
        echo "No domains found in $category category for brand $brand"
        return 1
    fi
}

# Function to export database (for backup or transfer)
export_database() {
    echo "# Enhanced Domain Database Export - $(date)"
    echo "# Format: BRAND|MAIN_DOMAINS|KAWAL_DOMAINS|FRESH_DOMAINS"
    echo "# Multiple domains per category are separated by commas"
    
    for brand in $(get_all_brands); do
        echo "$brand|${MAIN_DOMAINS[$brand]}|${KAWAL_DOMAINS[$brand]}|${FRESH_DOMAINS[$brand]}"
    done
}

# Function to import database from pipe-delimited format
import_database() {
    local import_file=$1
    
    if [[ ! -f "$import_file" ]]; then
        echo "Import file not found: $import_file"
        return 1
    fi
    
    echo "Importing database from: $import_file"
    local imported_count=0
    
    # Read file with proper handling of last line without newline
    while IFS='|' read -r brand main_domains kawal_domains fresh_domains || [[ -n "$brand" ]]; do
        # Skip comment lines and empty lines
        [[ "$brand" =~ ^#.*$ ]] && continue
        [[ -z "$brand" ]] && continue
        
        add_brand_to_db "$brand" "$main_domains" "$kawal_domains" "$fresh_domains"
        ((imported_count++))
    done < "$import_file"
    
    echo "Imported $imported_count brands."
}

# Function to get all domains from all categories for a brand (flat list)
get_all_domains_for_brand() {
    local brand=$1
    
    # Convert brand to uppercase
    brand=$(echo "$brand" | tr '[:lower:]' '[:upper:]')
    
    if ! brand_exists "$brand"; then
        return 1
    fi
    
    local all_domains=""
    
    # Add main domains
    if [[ -n "${MAIN_DOMAINS[$brand]}" ]]; then
        all_domains="${MAIN_DOMAINS[$brand]}"
    fi
    
    # Add kawal domains
    if [[ -n "${KAWAL_DOMAINS[$brand]}" ]]; then
        if [[ -n "$all_domains" ]]; then
            all_domains="$all_domains,${KAWAL_DOMAINS[$brand]}"
        else
            all_domains="${KAWAL_DOMAINS[$brand]}"
        fi
    fi
    
    # Add fresh domains
    if [[ -n "${FRESH_DOMAINS[$brand]}" ]]; then
        if [[ -n "$all_domains" ]]; then
            all_domains="$all_domains,${FRESH_DOMAINS[$brand]}"
        else
            all_domains="${FRESH_DOMAINS[$brand]}"
        fi
    fi
    
    echo "$all_domains"
    return 0
}

# Function to search for domains across all brands and categories
search_domains_global() {
    local search_term=$1
    local results=()
    
    for brand in $(get_all_brands); do
        # Check main domains
        if [[ -n "${MAIN_DOMAINS[$brand]}" ]]; then
            IFS=',' read -ra domains <<< "${MAIN_DOMAINS[$brand]}"
            for domain in "${domains[@]}"; do
                if [[ "$domain" == *"$search_term"* ]]; then
                    results+=("$brand:main:$domain")
                fi
            done
        fi
        
        # Check kawal domains
        if [[ -n "${KAWAL_DOMAINS[$brand]}" ]]; then
            IFS=',' read -ra domains <<< "${KAWAL_DOMAINS[$brand]}"
            for domain in "${domains[@]}"; do
                if [[ "$domain" == *"$search_term"* ]]; then
                    results+=("$brand:kawal:$domain")
                fi
            done
        fi
        
        # Check fresh domains
        if [[ -n "${FRESH_DOMAINS[$brand]}" ]]; then
            IFS=',' read -ra domains <<< "${FRESH_DOMAINS[$brand]}"
            for domain in "${domains[@]}"; do
                if [[ "$domain" == *"$search_term"* ]]; then
                    results+=("$brand:fresh:$domain")
                fi
            done
        fi
    done
    
    if [[ ${#results[@]} -gt 0 ]]; then
        for result in "${results[@]}"; do
            echo "$result"
        done
        return 0
    else
        return 1
    fi
}

# Function to reload data from file (useful for manual edits)
reload_domain_data() {
    echo "Reloading domain data from file..."
    load_domain_data_from_file
    local loaded_count=$(get_brand_count)
    echo "✓ Reloaded $loaded_count brands from: $DOMAIN_DATA_FILE"
}

# Auto-initialize database when file is sourced
init_domain_database