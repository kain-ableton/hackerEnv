#!/bin/bash
# core/scanner.sh - Network scanning functionality
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../lib/utils.sh"

function check_dependencies() {
    local missing_deps=()
    
    local required_tools=("nmap" "fping" "grep" "awk" "sed")
    local optional_tools=("xmlstarlet" "jq" "msfconsole" "hydra")
    
    log_info "Checking required dependencies..."
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
            log_error "Required tool missing: $tool"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_error "Install them with: apt install ${missing_deps[*]}"
        return 1
    fi
    
    log_info "Checking optional dependencies..."
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_warning "Optional tool missing: $tool (some features may be unavailable)"
        fi
    done
    
    log_success "All required dependencies found"
    return 0
}

function discover_hosts() {
    local network="$1"
    local output_file="$2"
    
    log_info "Starting host discovery for network: $network"
    
    safe_create_dir "$(dirname "$output_file")"
    
    # Use fping for fast host discovery
    if ! fping -a -g "$network" 2>/dev/null > "$output_file"; then
        log_warning "fping discovery may have encountered issues"
    fi
    
    # Verify with ping if configured
    local verified_file="${output_file}.verified"
    : > "$verified_file"
    
    while IFS= read -r ip; do
        if ping -c 1 -W 2 "$ip" &>/dev/null; then
            echo "$ip" >> "$verified_file"
            log_success "Host alive: $ip"
        fi
    done < "$output_file"
    
    mv "$verified_file" "$output_file"
    
    local host_count
    host_count=$(wc -l < "$output_file")
    log_info "Host discovery complete: $host_count hosts found"
    
    return 0
}

function scan_host() {
    local target="$1"
    local output_dir="$2"
    
    safe_create_dir "$output_dir"
    
    local nmap_opts=""
    local scan_mode="${SCAN_MODE:-normal}"
    local output_base="${output_dir}/nmap_${target}"
    
    # Determine nmap options based on scan mode
    case "$scan_mode" in
        quick)
            log_info "Starting QUICK scan on: $target (top 100 ports)"
            nmap_opts="-T4 -F --top-ports 100"
            ;;
        normal)
            log_info "Starting NORMAL scan on: $target"
            nmap_opts="${CONFIG_NMAP_OPTIONS:--sV -T4 -A -O}"
            ;;
        full)
            log_info "Starting FULL scan on: $target (all 65535 ports)"
            nmap_opts="-sV -sC -T4 -p- -A -O"
            log_warning "Full scan may take a long time"
            ;;
        stealth)
            log_info "Starting STEALTH scan on: $target"
            nmap_opts="-sS -T2 -f --data-length 25 -D RND:5"
            log_warning "Stealth mode - scan will be slow but harder to detect"
            ;;
        udp)
            log_info "Starting UDP scan on: $target"
            nmap_opts="-sU -sV --top-ports 100 -T4"
            log_warning "UDP scans are typically slow"
            ;;
        *)
            log_error "Unknown scan mode: $scan_mode"
            return 1
            ;;
    esac
    
    # Add aggressive scan options if enabled (overrides mode settings)
    if [ "${CONFIG_AGGRESSIVE_MODE:-false}" = "true" ]; then
        nmap_opts="$nmap_opts -p- -T5"
        log_warning "Aggressive mode enabled - scan will be very noisy"
    fi
    
    log_debug "Running: nmap $nmap_opts $target -oA $output_base"
    
    # First scan attempt
    if ! nmap $nmap_opts "$target" -oA "$output_base" 2>"${output_base}.err"; then
        log_error "Nmap scan failed for $target"
        if [ -f "${output_base}.err" ]; then
            cat "${output_base}.err" | tee -a "$LOG_FILE"
        fi
        return 1
    fi
    
    if [ ! -f "${output_base}.xml" ]; then
        log_error "Nmap XML output missing for $target"
        return 1
    fi
    
    # Check if host appears down
    if grep -q "Host seems down" "${output_base}.nmap" 2>/dev/null || \
       grep -q "0 hosts up" "${output_base}.nmap" 2>/dev/null; then
        log_warning "Host $target appears down, retrying with -Pn (skip host discovery)"
        
        # Retry with -Pn flag
        local retry_base="${output_dir}/nmap_${target}_retry"
        log_debug "Running: nmap $nmap_opts -Pn $target -oA $retry_base"
        
        if nmap $nmap_opts -Pn "$target" -oA "$retry_base" 2>"${retry_base}.err"; then
            # Check if retry found open ports
            if grep -q "open" "${retry_base}.nmap" 2>/dev/null; then
                log_success "Retry successful! Host is up with firewall blocking ping"
                # Replace original scan with retry results
                mv "${retry_base}.nmap" "${output_base}.nmap"
                mv "${retry_base}.xml" "${output_base}.xml"
                mv "${retry_base}.gnmap" "${output_base}.gnmap"
                rm -f "${retry_base}.err"
            else
                log_warning "Retry with -Pn found no open ports - host may truly be down"
                # Keep retry results as secondary scan
            fi
        else
            log_warning "Retry with -Pn also failed"
        fi
    fi
    
    log_success "Port scan completed for $target"
    
    # Parse results
    parse_scan_results "${output_base}.xml"
    
    # Run service-specific scripts if open ports found
    run_service_scripts "$target" "$output_dir"
    
    return 0
}

function parse_scan_results() {
    local xml_file="$1"
    
    if ! [ -f "$xml_file" ]; then
        log_error "Cannot parse scan results - file not found: $xml_file"
        return 1
    fi
    
    log_info "Parsing scan results..."
    
    # Extract open ports using xmlstarlet if available
    if command -v xmlstarlet &> /dev/null; then
        log_info "Open ports found:"
        xmlstarlet sel -t \
            -m "//port[state/@state='open']" \
            -v "@portid" -o "/" -v "@protocol" -o " " \
            -v "service/@name" -o " " \
            -v "service/@product" -o " " \
            -v "service/@version" -n \
            "$xml_file" | tee -a "$LOG_FILE"
    else
        # Fallback to grep
        log_info "Open ports found:"
        grep -oP 'portid="\K[^"]+' "$xml_file" | head -20 | tee -a "$LOG_FILE"
    fi
}

function scan_vulnerabilities() {
    local target="$1"
    local output_dir="$2"
    
    log_info "Starting vulnerability scan on: $target"
    
    safe_create_dir "$output_dir"
    
    local output_file="${output_dir}/vuln_scan_${target}"
    
    # Check if running as root (required for some vuln checks)
    local is_root=false
    if [ "$(id -u)" -eq 0 ]; then
        is_root=true
    fi
    
    # Check if vulnerability scripts are available
    local vuln_scripts=""
    
    # Check for vulners script (single file, not directory)
    if [ -f "/usr/share/nmap/scripts/vulners.nse" ]; then
        vuln_scripts="vulners"
    fi
    
    # Check for vulscan directory (needs trailing slash)
    if [ -d "/usr/share/nmap/scripts/vulscan" ]; then
        if [ -n "$vuln_scripts" ]; then
            vuln_scripts="$vuln_scripts,vulscan/"
        else
            vuln_scripts="vulscan/"
        fi
    fi
    
    # Use default vuln category if no specific scripts found
    if [ -z "$vuln_scripts" ]; then
        log_info "No additional vulnerability scripts found, using nmap default vuln category"
        vuln_scripts="vuln"
    fi
    
    log_debug "Running: nmap --script $vuln_scripts $target -oA $output_file"
    
    # Run vulnerability scan (non-privileged)
    if nmap --script "$vuln_scripts" "$target" -oA "$output_file" 2>"${output_file}.err"; then
        log_success "Vulnerability scan completed for $target"
    else
        # Check if it's a script error vs scan error
        if grep -q "failed to initialize the script engine" "${output_file}.err" 2>/dev/null; then
            log_warning "Vulnerability scripts not properly installed"
            log_info "Install vulners: cd /usr/share/nmap/scripts && sudo wget https://raw.githubusercontent.com/vulnersCom/nmap-vulners/master/vulners.nse"
            # Remove failed scan files
            rm -f "${output_file}".{nmap,xml,gnmap,err} 2>/dev/null
            return 0
        else
            log_warning "Vulnerability scan encountered errors for $target (this is normal without root)"
        fi
    fi
    
    return 0
}

function extract_services() {
    local xml_file="$1"
    local output_dir="$(dirname "$xml_file")"
    
    log_debug "Extracting service information from: $xml_file"
    
    # Extract unique service names
    grep -oP 'service name="\K[^"]+' "$xml_file" | sort -u > "${output_dir}/services.txt" || true
    
    # Extract product versions
    grep -oP 'product="\K[^"]+' "$xml_file" | sort -u > "${output_dir}/products.txt" || true
    grep -oP 'version="\K[^"]+' "$xml_file" | sort -u > "${output_dir}/versions.txt" || true
    
    # Extract OS information
    grep -oP 'osclass type="\K[^"]+' "$xml_file" | head -1 > "${output_dir}/os.txt" || true
    
    log_debug "Service information extracted to: $output_dir"
}

function generate_scan_summary() {
    local scan_dir="$1"
    local summary_file="${scan_dir}/scan_summary.txt"
    
    {
        echo "=================================="
        echo "Scan Summary"
        echo "=================================="
        echo "Date: $(date)"
        echo "Target: $(basename "$scan_dir")"
        echo ""
        
        if [ -f "${scan_dir}/services.txt" ]; then
            echo "Services Detected:"
            cat "${scan_dir}/services.txt"
            echo ""
        fi
        
        if [ -f "${scan_dir}/os.txt" ]; then
            echo "Operating System:"
            cat "${scan_dir}/os.txt"
            echo ""
        fi
        
        # Check if any nmap files exist
        local nmap_found=false
        for nmap_file in "${scan_dir}"/nmap_*.nmap; do
            if [ -f "$nmap_file" ]; then
                nmap_found=true
                break
            fi
        done
        
        if [ "$nmap_found" = true ]; then
            echo "Open Ports:"
            grep "open" "${scan_dir}"/nmap_*.nmap | grep -v "Warning" | head -20
        fi
    } > "$summary_file"
    
    log_info "Scan summary saved to: $summary_file"
}

function run_service_scripts() {
    local target="$1"
    local output_dir="$2"
    local xml_file="${output_dir}/nmap_${target}.xml"
    
    if [ ! -f "$xml_file" ]; then
        log_debug "No XML file found, skipping service scripts"
        return 0
    fi
    
    log_info "Running service-specific nmap scripts for $target"
    
    # Extract services and ports from XML
    local services_file="${output_dir}/services.txt"
    if [ ! -f "$services_file" ] || [ ! -s "$services_file" ]; then
        log_debug "No services detected, skipping service scripts"
        return 0
    fi
    
    # Count services for logging
    local service_count=$(wc -l < "$services_file")
    log_debug "Found $service_count service(s) to analyze"
    
    # Map services to nmap script categories
    local script_output="${output_dir}/service_scripts_${target}"
    local scripts_run=0
    local services_checked=0
    
    while IFS= read -r service; do
        services_checked=$((services_checked + 1))
        local scripts=""
        
        case "$service" in
            http|http-*|https|ssl|www)
                scripts="http-enum,http-headers,http-methods,http-robots.txt,http-title,http-shellshock,http-vuln-*"
                log_info "Running HTTP/HTTPS enumeration scripts on $target"
                ;;
            ssh)
                scripts="ssh-auth-methods,ssh-hostkey,ssh2-enum-algos,sshv1"
                log_info "Running SSH enumeration scripts on $target"
                ;;
            ftp)
                scripts="ftp-anon,ftp-bounce,ftp-brute,ftp-proftpd-backdoor,ftp-vsftpd-backdoor"
                log_info "Running FTP enumeration scripts on $target"
                ;;
            smb|microsoft-ds|netbios-ssn)
                scripts="smb-enum-shares,smb-enum-users,smb-os-discovery,smb-protocols,smb-security-mode,smb-vuln-*"
                log_info "Running SMB enumeration scripts on $target"
                ;;
            mysql|mariadb)
                scripts="mysql-info,mysql-empty-password,mysql-users,mysql-databases,mysql-vuln-*"
                log_info "Running MySQL/MariaDB enumeration scripts on $target"
                ;;
            postgresql)
                scripts="pgsql-brute,postgresql-databases,postgresql-brute"
                log_info "Running PostgreSQL enumeration scripts on $target"
                ;;
            smtp|submission)
                scripts="smtp-commands,smtp-enum-users,smtp-open-relay,smtp-vuln-*"
                log_info "Running SMTP enumeration scripts on $target"
                ;;
            dns|domain)
                scripts="dns-zone-transfer,dns-nsid,dns-recursion,dns-service-discovery"
                log_info "Running DNS enumeration scripts on $target"
                ;;
            rdp|ms-wbt-server)
                scripts="rdp-enum-encryption,rdp-vuln-ms12-020"
                log_info "Running RDP enumeration scripts on $target"
                ;;
            vnc)
                scripts="vnc-info,vnc-brute"
                log_info "Running VNC enumeration scripts on $target"
                ;;
            snmp)
                scripts="snmp-info,snmp-processes,snmp-sysdescr,snmp-win32-services"
                log_info "Running SNMP enumeration scripts on $target"
                ;;
            ldap)
                scripts="ldap-rootdse,ldap-search,ldap-brute"
                log_info "Running LDAP enumeration scripts on $target"
                ;;
            mongodb)
                scripts="mongodb-info,mongodb-databases,mongodb-brute"
                log_info "Running MongoDB enumeration scripts on $target"
                ;;
            redis)
                scripts="redis-info,redis-brute"
                log_info "Running Redis enumeration scripts on $target"
                ;;
            *)
                # Log unknown services for debugging
                log_debug "No specific scripts for service: $service"
                continue
                ;;
        esac
        
        if [ -n "$scripts" ]; then
            local service_output="${script_output}_${service}"
            log_debug "Running: nmap --script $scripts -sV $target -oA $service_output"
            
            if nmap --script "$scripts" -sV "$target" -oA "$service_output" 2>&1 | tee "${service_output}.err" >/dev/null; then
                scripts_run=$((scripts_run + 1))
            fi
        fi
    done < "$services_file"
    
    if [ $scripts_run -gt 0 ]; then
        log_success "Ran service-specific scripts for $scripts_run service(s)"
    else
        log_info "No recognized services found for specialized scripts (checked $services_checked service(s))"
    fi
    
    return 0
}

export -f check_dependencies discover_hosts scan_host parse_scan_results
export -f scan_vulnerabilities extract_services generate_scan_summary run_service_scripts
