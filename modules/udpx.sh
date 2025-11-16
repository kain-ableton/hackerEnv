#!/bin/bash
# modules/udpx.sh - UDPX UDP Scanner Integration
# Fast single-packet UDP scanner for service discovery

set -euo pipefail

# UDPX Configuration
UDPX_DEFAULT_TIMEOUT=500
UDPX_DEFAULT_CONCURRENCY=32
UDPX_SUPPORTED_SERVICES=(
    "ard" "bacnet" "bacnet_rpm" "chargen" "citrix" "coap" "db" "digi1" 
    "digi2" "digi3" "dns" "ipmi" "ldap" "mdns" "memcache" "mssql" 
    "nat_port_mapping" "natpmp" "netbios" "netis" "ntp" "ntp_monlist" 
    "openvpn" "pca_nq" "pca_st" "pcanywhere" "portmap" "qotd" "rdp" 
    "ripv" "sentinel" "sip" "snmp1" "snmp2" "snmp3" "ssdp" "tftp" 
    "ubiquiti" "ubiquiti_discovery_v1" "ubiquiti_discovery_v2" "upnp" 
    "valve" "wdbrpc" "wsd" "wsd_malformed" "xdmcp" "kerberos" "ike"
)

function check_udpx_installed() {
    if ! command -v udpx &> /dev/null; then
        log_warn "UDPX not installed. Install with: go install github.com/nullt3r/udpx/cmd/udpx@latest"
        return 1
    fi
    return 0
}

function install_udpx() {
    log_info "Installing UDPX UDP scanner..."
    
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go first."
        log_info "Install Go: sudo apt install golang-go -y"
        return 1
    fi
    
    log_info "Installing UDPX via Go..."
    if go install -v github.com/nullt3r/udpx/cmd/udpx@latest 2>&1 | log_debug; then
        log_success "UDPX installed successfully"
        
        # Add to PATH if not already there
        if ! command -v udpx &> /dev/null; then
            local go_bin="${HOME}/go/bin"
            if [ -f "${go_bin}/udpx" ]; then
                log_info "UDPX binary located at: ${go_bin}/udpx"
                log_info "Add to PATH: export PATH=\$PATH:${go_bin}"
            fi
        fi
        return 0
    else
        log_error "Failed to install UDPX"
        return 1
    fi
}

function udpx_scan_target() {
    local target="$1"
    local output_dir="$2"
    local concurrency="${3:-$UDPX_DEFAULT_CONCURRENCY}"
    local timeout="${4:-$UDPX_DEFAULT_TIMEOUT}"
    
    if ! check_udpx_installed; then
        log_warn "UDPX not available, skipping UDP scan"
        return 1
    fi
    
    local udpx_dir="${output_dir}/udpx"
    mkdir -p "$udpx_dir"
    
    local output_file="${udpx_dir}/udpx_scan.jsonl"
    local summary_file="${udpx_dir}/udpx_summary.txt"
    
    log_info "Starting UDPX UDP scan on ${target}"
    log_info "Concurrency: ${concurrency}, Timeout: ${timeout}ms"
    
    # Run UDPX scan
    local udpx_cmd="udpx -t ${target} -c ${concurrency} -w ${timeout} -o ${output_file}"
    
    if [ "$VERBOSITY" -ge 2 ]; then
        udpx_cmd="${udpx_cmd} -sp"  # Show packets in verbose mode
    fi
    
    log_verbose "Running: ${udpx_cmd}"
    
    if eval "$udpx_cmd" 2>&1 | tee "${udpx_dir}/udpx_output.log"; then
        log_success "UDPX scan completed"
        
        # Generate summary
        udpx_generate_summary "$output_file" "$summary_file"
        
        # Parse and display results
        udpx_parse_results "$output_file"
        
        return 0
    else
        log_error "UDPX scan failed"
        return 1
    fi
}

function udpx_scan_specific_service() {
    local target="$1"
    local service="$2"
    local output_dir="$3"
    local concurrency="${4:-$UDPX_DEFAULT_CONCURRENCY}"
    local timeout="${5:-$UDPX_DEFAULT_TIMEOUT}"
    
    if ! check_udpx_installed; then
        return 1
    fi
    
    # Validate service
    if ! printf '%s\n' "${UDPX_SUPPORTED_SERVICES[@]}" | grep -qx "$service"; then
        log_error "Unsupported service: ${service}"
        log_info "Supported services: ${UDPX_SUPPORTED_SERVICES[*]}"
        return 1
    fi
    
    local udpx_dir="${output_dir}/udpx"
    mkdir -p "$udpx_dir"
    
    local output_file="${udpx_dir}/udpx_${service}.jsonl"
    
    log_info "Scanning for ${service} service on ${target}"
    
    local udpx_cmd="udpx -t ${target} -s ${service} -c ${concurrency} -w ${timeout} -o ${output_file}"
    
    if eval "$udpx_cmd" 2>&1 | tee "${udpx_dir}/udpx_${service}_output.log"; then
        log_success "UDPX ${service} scan completed"
        udpx_parse_results "$output_file"
        return 0
    else
        log_error "UDPX ${service} scan failed"
        return 1
    fi
}

function udpx_generate_summary() {
    local jsonl_file="$1"
    local summary_file="$2"
    
    if [ ! -f "$jsonl_file" ]; then
        log_warn "No UDPX results file found"
        return 1
    fi
    
    log_verbose "Generating UDPX summary..."
    
    {
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                    UDPX UDP SCAN SUMMARY                       ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Scan Date: $(date)"
        echo ""
        
        local total_results=$(wc -l < "$jsonl_file")
        echo "Total Services Found: ${total_results}"
        echo ""
        
        if [ "$total_results" -gt 0 ]; then
            echo "Services Discovered:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Parse and display services
            while IFS= read -r line; do
                local address=$(echo "$line" | grep -oP '"address":"\K[^"]+' || echo "N/A")
                local port=$(echo "$line" | grep -oP '"port":\K[0-9]+' || echo "N/A")
                local service=$(echo "$line" | grep -oP '"service":"\K[^"]+' || echo "N/A")
                local hostname=$(echo "$line" | grep -oP '"hostname":"\K[^"]+' || echo "")
                
                if [ -n "$hostname" ]; then
                    printf "  %-15s  %-6s  %-15s  (%s)\n" "$address" "$port" "$service" "$hostname"
                else
                    printf "  %-15s  %-6s  %-15s\n" "$address" "$port" "$service"
                fi
            done < "$jsonl_file"
            
            echo ""
            echo "Service Statistics:"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Count services
            grep -oP '"service":"\K[^"]+' "$jsonl_file" | sort | uniq -c | sort -rn | while read -r count svc; do
                printf "  %-20s %3d\n" "$svc" "$count"
            done
            
            echo ""
        else
            echo "No UDP services discovered."
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Full results: ${jsonl_file}"
        echo ""
        
    } > "$summary_file"
    
    # Display summary in terminal
    if [ "$VERBOSITY" -ge 1 ]; then
        cat "$summary_file"
    fi
    
    log_success "UDPX summary saved to: ${summary_file}"
}

function udpx_parse_results() {
    local jsonl_file="$1"
    
    if [ ! -f "$jsonl_file" ] || [ ! -s "$jsonl_file" ]; then
        log_info "No UDP services discovered"
        return 0
    fi
    
    local total=$(wc -l < "$jsonl_file")
    
    if [ "$total" -gt 0 ]; then
        log_success "Found ${total} UDP service(s)"
        
        if [ "$VERBOSITY" -ge 1 ]; then
            echo ""
            echo "${GREEN}═══════════════════════════════════════════════════════════${RESET}"
            echo "${BOLD}  UDP Services Discovered${RESET}"
            echo "${GREEN}═══════════════════════════════════════════════════════════${RESET}"
            
            while IFS= read -r line; do
                local address=$(echo "$line" | grep -oP '"address":"\K[^"]+' || echo "N/A")
                local port=$(echo "$line" | grep -oP '"port":\K[0-9]+' || echo "N/A")
                local service=$(echo "$line" | grep -oP '"service":"\K[^"]+' || echo "N/A")
                
                echo -e "  ${CYAN}►${RESET} ${address}:${port} - ${YELLOW}${service}${RESET}"
            done < "$jsonl_file"
            
            echo "${GREEN}═══════════════════════════════════════════════════════════${RESET}"
            echo ""
        fi
    fi
}

function udpx_check_interesting_services() {
    local jsonl_file="$1"
    
    if [ ! -f "$jsonl_file" ]; then
        return 0
    fi
    
    # High-value services to highlight
    local interesting_services=("ipmi" "snmp1" "snmp2" "snmp3" "ike" "openvpn" "kerberos" "ldap" "memcache")
    local found_interesting=false
    
    for service in "${interesting_services[@]}"; do
        if grep -q "\"service\":\"${service}\"" "$jsonl_file"; then
            if [ "$found_interesting" = false ]; then
                echo ""
                log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_warn "  ⚠️  INTERESTING UDP SERVICES FOUND"
                log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                found_interesting=true
            fi
            
            grep "\"service\":\"${service}\"" "$jsonl_file" | while IFS= read -r line; do
                local address=$(echo "$line" | grep -oP '"address":"\K[^"]+')
                local port=$(echo "$line" | grep -oP '"port":\K[0-9]+')
                log_warn "  ⚡ ${service^^} - ${address}:${port}"
            done
        fi
    done
    
    if [ "$found_interesting" = true ]; then
        log_warn "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
    fi
}

function udpx_export_to_nmap_format() {
    local jsonl_file="$1"
    local output_file="$2"
    
    if [ ! -f "$jsonl_file" ]; then
        return 1
    fi
    
    log_verbose "Exporting UDPX results to Nmap-compatible format..."
    
    {
        echo "# UDPX UDP Scan Results (Nmap-compatible format)"
        echo "# Generated: $(date)"
        echo ""
        
        while IFS= read -r line; do
            local address=$(echo "$line" | grep -oP '"address":"\K[^"]+')
            local port=$(echo "$line" | grep -oP '"port":\K[0-9]+')
            local service=$(echo "$line" | grep -oP '"service":"\K[^"]+')
            
            echo "${address}:${port} open udp ${service}"
        done < "$jsonl_file"
        
    } > "$output_file"
    
    log_success "Nmap-compatible format saved to: ${output_file}"
}

function udpx_show_supported_services() {
    # Load colors if not already loaded
    if [ -z "${BOLD:-}" ]; then
        BOLD="\033[1m"
        RESET="\033[0m"
    fi
    
    echo ""
    echo -e "${BOLD}UDPX Supported Services (${#UDPX_SUPPORTED_SERVICES[@]}):${RESET}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local count=0
    for service in "${UDPX_SUPPORTED_SERVICES[@]}"; do
        printf "  %-25s" "$service"
        ((count++))
        if [ $((count % 3)) -eq 0 ]; then
            echo ""
        fi
    done
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Export functions
export -f check_udpx_installed
export -f install_udpx
export -f udpx_scan_target
export -f udpx_scan_specific_service
export -f udpx_generate_summary
export -f udpx_parse_results
export -f udpx_check_interesting_services
export -f udpx_export_to_nmap_format
export -f udpx_show_supported_services
