#!/bin/bash
# toolchains/database_toolchain.sh - Database Assessment Toolchain
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

TOOLCHAIN_NAME="DATABASE"
TOOLCHAIN_VERSION="2.0"

function database_toolchain_check_tools() {
    local tools=("nmap" "mysql" "psql" "mongo" "redis-cli")
    
    log_info "[$TOOLCHAIN_NAME] Checking available database tools..."
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_success "[$TOOLCHAIN_NAME] Found: $tool"
        else
            log_debug "[$TOOLCHAIN_NAME] Missing: $tool"
        fi
    done
    
    return 0
}

function database_toolchain_mysql() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-3306}"
    
    if ! command -v mysql &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] mysql client not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Testing MySQL on $target:$port"
    
    local output_file="${output_dir}/mysql_${target}.txt"
    
    {
        echo "=== MySQL Enumeration ==="
        echo "Target: $target:$port"
        echo ""
        
        # Test anonymous access
        echo "Testing anonymous access..."
        timeout 5 mysql -h "$target" -P "$port" -e "SELECT VERSION();" 2>&1 || echo "Anonymous access denied"
        
        # Test root with no password
        echo ""
        echo "Testing root with no password..."
        timeout 5 mysql -h "$target" -P "$port" -u root -e "SELECT VERSION();" 2>&1 || echo "Root access denied"
        
    } > "$output_file"
    
    if grep -qi "version\|database" "$output_file" 2>/dev/null; then
        log_warning "[$TOOLCHAIN_NAME] MySQL access possible (potential security issue)"
        echo "VULNERABILITY: MySQL weak/no authentication" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] MySQL access properly restricted"
    fi
    
    return 0
}

function database_toolchain_postgresql() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-5432}"
    
    if ! command -v psql &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] psql client not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Testing PostgreSQL on $target:$port"
    
    local output_file="${output_dir}/postgresql_${target}.txt"
    
    {
        echo "=== PostgreSQL Enumeration ==="
        echo "Target: $target:$port"
        echo ""
        
        # Test postgres user with no password
        echo "Testing postgres user..."
        timeout 5 psql -h "$target" -p "$port" -U postgres -c "SELECT version();" 2>&1 || echo "Access denied"
        
    } > "$output_file"
    
    if grep -qi "postgresql\|version" "$output_file" 2>/dev/null; then
        log_warning "[$TOOLCHAIN_NAME] PostgreSQL access possible"
        echo "VULNERABILITY: PostgreSQL weak/no authentication" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] PostgreSQL access properly restricted"
    fi
    
    return 0
}

function database_toolchain_mongodb() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-27017}"
    
    if ! command -v mongo &> /dev/null && ! command -v mongosh &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] mongo client not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Testing MongoDB on $target:$port"
    
    local output_file="${output_dir}/mongodb_${target}.txt"
    local mongo_cmd="mongo"
    
    # Use mongosh if available (newer versions)
    if command -v mongosh &> /dev/null; then
        mongo_cmd="mongosh"
    fi
    
    {
        echo "=== MongoDB Enumeration ==="
        echo "Target: $target:$port"
        echo ""
        
        # Test unauthenticated access
        echo "Testing unauthenticated access..."
        timeout 5 $mongo_cmd --host "$target" --port "$port" --eval "db.version()" 2>&1 || echo "Access denied"
        
        echo ""
        echo "Listing databases..."
        timeout 5 $mongo_cmd --host "$target" --port "$port" --eval "show dbs" 2>&1 || echo "Cannot list databases"
        
    } > "$output_file"
    
    if grep -qi "version\|admin\|config" "$output_file" 2>/dev/null; then
        log_warning "[$TOOLCHAIN_NAME] MongoDB unauthenticated access (CRITICAL!)"
        echo "CRITICAL: MongoDB no authentication" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] MongoDB access properly restricted"
    fi
    
    return 0
}

function database_toolchain_redis() {
    local target="$1"
    local output_dir="$2"
    local port="${3:-6379}"
    
    if ! command -v redis-cli &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] redis-cli not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Testing Redis on $target:$port"
    
    local output_file="${output_dir}/redis_${target}.txt"
    
    {
        echo "=== Redis Enumeration ==="
        echo "Target: $target:$port"
        echo ""
        
        # Test unauthenticated access
        echo "Testing unauthenticated access..."
        timeout 5 redis-cli -h "$target" -p "$port" INFO 2>&1 || echo "Access denied"
        
        echo ""
        echo "Testing PING..."
        timeout 5 redis-cli -h "$target" -p "$port" PING 2>&1 || echo "No response"
        
    } > "$output_file"
    
    if grep -qi "redis_version\|pong" "$output_file" 2>/dev/null; then
        log_warning "[$TOOLCHAIN_NAME] Redis unauthenticated access (security risk)"
        echo "VULNERABILITY: Redis no authentication" >> "${output_dir}/vulnerabilities.txt"
    else
        log_info "[$TOOLCHAIN_NAME] Redis access properly restricted"
    fi
    
    return 0
}

function database_toolchain_nmap_scripts() {
    local target="$1"
    local output_dir="$2"
    
    if ! command -v nmap &> /dev/null; then
        log_debug "[$TOOLCHAIN_NAME] nmap not available"
        return 1
    fi
    
    log_info "[$TOOLCHAIN_NAME] Running nmap database scripts on $target"
    
    local output_file="${output_dir}/database_nmap_scripts_${target}.txt"
    
    # Run database-related nmap scripts
    if timeout 300 nmap --script "mysql-*,pgsql-*,mongodb-*,redis-*" \
        -p 3306,5432,27017,6379 "$target" -oN "$output_file" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "[$TOOLCHAIN_NAME] Nmap database scripts completed"
    else
        log_warning "[$TOOLCHAIN_NAME] Nmap database scripts failed"
    fi
    
    return 0
}

function database_toolchain_run() {
    local target="$1"
    local output_dir="$2"
    
    log_info "[$TOOLCHAIN_NAME] Starting database toolchain for $target"
    
    local toolchain_dir="${output_dir}/database_toolchain"
    safe_create_dir "$toolchain_dir"
    
    database_toolchain_check_tools
    
    # Test each database type
    database_toolchain_mysql "$target" "$toolchain_dir" 3306
    database_toolchain_postgresql "$target" "$toolchain_dir" 5432
    database_toolchain_mongodb "$target" "$toolchain_dir" 27017
    database_toolchain_redis "$target" "$toolchain_dir" 6379
    
    # Run nmap scripts
    database_toolchain_nmap_scripts "$target" "$toolchain_dir"
    
    local summary_file="${toolchain_dir}/database_toolchain_summary.txt"
    {
        echo "=================================="
        echo "Database Toolchain Summary"
        echo "=================================="
        echo "Target: $target"
        echo "Date: $(date)"
        echo ""
        echo "Databases Tested:"
        [ -f "${toolchain_dir}/mysql_${target}.txt" ] && echo "  ✓ MySQL (3306)"
        [ -f "${toolchain_dir}/postgresql_${target}.txt" ] && echo "  ✓ PostgreSQL (5432)"
        [ -f "${toolchain_dir}/mongodb_${target}.txt" ] && echo "  ✓ MongoDB (27017)"
        [ -f "${toolchain_dir}/redis_${target}.txt" ] && echo "  ✓ Redis (6379)"
        [ -f "${toolchain_dir}/database_nmap_scripts_${target}.txt" ] && echo "  ✓ Nmap scripts"
        echo ""
        echo "Key Findings:"
        
        local critical=false
        if grep -q "weak/no authentication" "${toolchain_dir}"/*.txt 2>/dev/null; then
            echo "  ⚠ Weak or no authentication detected"
            critical=true
        fi
        if grep -q "CRITICAL\|unauthenticated access" "${toolchain_dir}"/*.txt 2>/dev/null; then
            echo "  ⚠ CRITICAL: Unauthenticated database access"
            critical=true
        fi
        
        if [ "$critical" = false ]; then
            echo "  ✓ No critical issues found"
        fi
    } > "$summary_file"
    
    log_success "[$TOOLCHAIN_NAME] Database toolchain completed"
    
    return 0
}

export -f database_toolchain_check_tools database_toolchain_mysql database_toolchain_postgresql
export -f database_toolchain_mongodb database_toolchain_redis database_toolchain_nmap_scripts
export -f database_toolchain_run
