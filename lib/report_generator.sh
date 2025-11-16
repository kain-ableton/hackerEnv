#!/bin/bash
# lib/report_generator.sh - HTML and DOCX Report Generation
# Version: 2.0

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

REPORT_VERSION="2.0"

# Generate HTML report header
function generate_html_header() {
    local title="$1"
    
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>HackerEnv Penetration Test Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            line-height: 1.6;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .content {
            padding: 40px;
        }
        .section {
            margin-bottom: 40px;
            border-left: 4px solid #667eea;
            padding-left: 20px;
        }
        .section h2 {
            color: #2a5298;
            margin-bottom: 20px;
            font-size: 1.8em;
        }
        .section h3 {
            color: #667eea;
            margin: 20px 0 10px 0;
            font-size: 1.3em;
        }
        .info-box {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 15px 0;
            border: 1px solid #dee2e6;
        }
        .info-box strong {
            color: #2a5298;
        }
        .critical {
            background: #ffe6e6;
            border-left: 4px solid #dc3545;
            padding: 15px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .high {
            background: #fff3cd;
            border-left: 4px solid #ffc107;
            padding: 15px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .medium {
            background: #e7f3ff;
            border-left: 4px solid #17a2b8;
            padding: 15px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .low {
            background: #d4edda;
            border-left: 4px solid #28a745;
            padding: 15px;
            margin: 10px 0;
            border-radius: 4px;
        }
        .code-block {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 6px;
            overflow-x: auto;
            font-family: 'Courier New', monospace;
            margin: 10px 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        th {
            background: #2a5298;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 12px;
            border-bottom: 1px solid #dee2e6;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .footer {
            background: #2d2d2d;
            color: white;
            padding: 20px;
            text-align: center;
        }
        .badge {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.85em;
            font-weight: bold;
        }
        .badge-critical { background: #dc3545; color: white; }
        .badge-high { background: #ffc107; color: #2d2d2d; }
        .badge-medium { background: #17a2b8; color: white; }
        .badge-low { background: #28a745; color: white; }
        .badge-info { background: #6c757d; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 HackerEnv v2.0</h1>
            <p>Penetration Testing Report</p>
            <p style="font-size: 0.9em; margin-top: 10px;">Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
        <div class="content">
EOF
}

# Generate HTML report footer
function generate_html_footer() {
    cat << 'EOF'
        </div>
        <div class="footer">
            <p>HackerEnv v2.0 - Automated Penetration Testing Framework</p>
            <p style="margin-top: 10px; font-size: 0.9em;">
                ⚠️ This report contains sensitive security information - Handle with care
            </p>
        </div>
    </div>
</body>
</html>
EOF
}

# Generate executive summary section
function generate_executive_summary() {
    local target_count="$1"
    local total_hosts="$2"
    local total_vulns="$3"
    
    cat << EOF
<div class="section">
    <h2>📊 Executive Summary</h2>
    <div class="info-box">
        <p><strong>Scan Date:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
        <p><strong>Targets Scanned:</strong> $target_count</p>
        <p><strong>Hosts Discovered:</strong> $total_hosts</p>
        <p><strong>Vulnerabilities Found:</strong> $total_vulns</p>
    </div>
</div>
EOF
}

# Generate target details section
function generate_target_section() {
    local target_dir="$1"
    local target
    target=$(basename "$target_dir")
    
    cat << EOF
<div class="section">
    <h2>🎯 Target: $target</h2>
EOF
    
    # System information
    echo "<h3>System Information</h3>"
    echo "<div class='info-box'>"
    if [ -f "${target_dir}/nmap_${target}.nmap" ]; then
        local os_info
        os_info=$(grep -i "OS:\|Running:" "${target_dir}/nmap_${target}.nmap" | head -3 || echo "OS not detected")
        echo "<p><strong>Operating System:</strong> $os_info</p>"
    fi
    echo "<p><strong>Scan Date:</strong> $(stat -c %y "$target_dir" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)</p>"
    echo "</div>"
    
    # Open ports
    if [ -f "${target_dir}/nmap_${target}.nmap" ]; then
        echo "<h3>Open Ports & Services</h3>"
        echo "<table>"
        echo "<tr><th>Port</th><th>State</th><th>Service</th><th>Version</th></tr>"
        
        grep "open" "${target_dir}/nmap_${target}.nmap" | grep -v "Warning" | head -20 | while read -r line; do
            local port
            port=$(echo "$line" | awk '{print $1}')
            local service
            service=$(echo "$line" | awk '{print $3}')
            local version
            version=$(echo "$line" | cut -d' ' -f4-)
            
            echo "<tr><td><strong>$port</strong></td>"
            echo "<td><span class='badge badge-low'>OPEN</span></td>"
            echo "<td>$service</td>"
            echo "<td>$version</td></tr>"
        done
        
        echo "</table>"
    fi
    
    # Vulnerability highlights
    echo "<h3>⚠️ Security Findings</h3>"
    local found_vulns=false
    
    # Check for vulnerable services
    if [ -f "${target_dir}/nmap_${target}.nmap" ]; then
        if grep -qi "vulnerable\|exploit\|backdoor" "${target_dir}/nmap_${target}.nmap"; then
            echo "<div class='critical'>"
            echo "<strong>Potential Vulnerabilities Detected:</strong><br>"
            grep -i "vulnerable\|exploit\|backdoor" "${target_dir}/nmap_${target}.nmap" | head -5
            echo "</div>"
            found_vulns=true
        fi
    fi
    
    # Toolchain results
    for toolchain_dir in "${target_dir}"/*_toolchain; do
        if [ -d "$toolchain_dir" ]; then
            local toolchain_name
            toolchain_name=$(basename "$toolchain_dir" | sed 's/_toolchain//')
            echo "<h3>🔧 ${toolchain_name^^} Toolchain Results</h3>"
            
            # Find and display key findings
            if [ -f "${toolchain_dir}/${toolchain_name}_toolchain_summary.txt" ]; then
                echo "<div class='code-block'>"
                cat "${toolchain_dir}/${toolchain_name}_toolchain_summary.txt" | head -30
                echo "</div>"
            fi
            
            # Check for findings in toolchain outputs
            if grep -rqi "vulnerable\|critical\|high\|exposed" "$toolchain_dir" 2>/dev/null; then
                echo "<div class='high'>"
                echo "<strong>⚠️ Security Issues Found:</strong><br>"
                grep -rhi "vulnerable\|critical\|high\|exposed" "$toolchain_dir" 2>/dev/null | head -5
                echo "</div>"
            fi
        fi
    done
    
    # Metasploit results
    if [ -d "${target_dir}/metasploit" ]; then
        echo "<h3>🎯 Metasploit Exploitation Attempts</h3>"
        echo "<div class='info-box'>"
        echo "<strong>Resource Files Generated:</strong><br>"
        for rc_file in "${target_dir}/metasploit"/*.rc; do
            if [ -f "$rc_file" ]; then
                local exploit_name
                exploit_name=$(basename "$rc_file" .rc)
                echo "<p>📄 $exploit_name</p>"
            fi
        done
        
        # Check for successful exploits
        local exploits_success=false
        for log_file in "${target_dir}/metasploit"/msf_*.log; do
            if [ -f "$log_file" ] && grep -q "session.*opened\|Sending stage\|Command shell" "$log_file" 2>/dev/null; then
                if [ "$exploits_success" = false ]; then
                    echo "<div class='critical' style='margin-top: 15px;'>"
                    echo "<strong>⚠️ CRITICAL: Potential Successful Exploitation!</strong><br>"
                    exploits_success=true
                fi
                echo "<p>✓ $(basename "$log_file")</p>"
            fi
        done
        if [ "$exploits_success" = true ]; then
            echo "</div>"
        fi
        echo "</div>"
        
        # Add summary link
        if [ -f "${target_dir}/metasploit/metasploit_summary.txt" ]; then
            echo "<p><a href='file://$(realpath "${target_dir}/metasploit/metasploit_summary.txt")' style='color: #667eea;'>View Detailed Metasploit Summary →</a></p>"
        fi
    fi
    
    # Hydra results
    if [ -d "${target_dir}/hydra" ]; then
        echo "<h3>🔑 Brute Force Results</h3>"
        local found_creds=false
        for bf_file in "${target_dir}/hydra"/*_bruteforce.txt; do
            if [ -f "$bf_file" ]; then
                if grep -q "login:" "$bf_file" 2>/dev/null; then
                    if [ "$found_creds" = false ]; then
                        echo "<div class='critical'>"
                        echo "<strong>⚠️ CRITICAL: CREDENTIALS FOUND!</strong><br><br>"
                        found_creds=true
                    fi
                    local service
                    service=$(basename "$bf_file" _bruteforce.txt)
                    echo "<p><strong>Service: ${service^^}</strong></p>"
                    echo "<pre style='background: #1a1a1a; color: #0f0; padding: 10px; border-radius: 4px;'>"
                    grep "login:" "$bf_file" | head -5
                    echo "</pre>"
                fi
            fi
        done
        if [ "$found_creds" = true ]; then
            echo "</div>"
        else
            echo "<div class='low'>"
            echo "<p>No credentials found through brute force attacks</p>"
            echo "</div>"
        fi
        
        # Add summary link
        if [ -f "${target_dir}/hydra/hydra_summary.txt" ]; then
            echo "<p><a href='file://$(realpath "${target_dir}/hydra/hydra_summary.txt")' style='color: #667eea;'>View Detailed Hydra Summary →</a></p>"
        fi
    fi
    
    # Warning if no vulns found
    if [ "$found_vulns" = false ]; then
        echo "<div class='low'>"
        echo "<p>No obvious vulnerabilities detected in automated scans. Manual review recommended.</p>"
        echo "</div>"
    fi
    
    echo "</div>"
}

# Generate main HTML report
function generate_html_report() {
    local targets_dir="$1"
    local output_file="$2"
    
    log_info "[REPORT] Generating HTML report: $output_file"
    
    {
        generate_html_header "HackerEnv Report"
        
        # Count targets
        local target_count=0
        local total_hosts=0
        
        for target_dir in "${targets_dir}"/*; do
            if [ -d "$target_dir" ]; then
                target_count=$((target_count + 1))
                total_hosts=$((total_hosts + 1))
            fi
        done
        
        generate_executive_summary "$target_count" "$total_hosts" "N/A"
        
        # Generate section for each target
        for target_dir in "${targets_dir}"/*; do
            if [ -d "$target_dir" ]; then
                generate_target_section "$target_dir"
            fi
        done
        
        generate_html_footer
        
    } > "$output_file"
    
    log_success "[REPORT] HTML report generated: $output_file"
    log_info "[REPORT] View at: file://$(realpath "$output_file")"
}

# Generate DOCX report (requires pandoc)
function generate_docx_report() {
    local html_file="$1"
    local docx_file="$2"
    
    if ! command -v pandoc &>/dev/null; then
        log_warning "[REPORT] pandoc not installed - DOCX generation skipped"
        log_info "[REPORT] Install with: apt install pandoc"
        return 1
    fi
    
    log_info "[REPORT] Generating DOCX report: $docx_file"
    
    if pandoc "$html_file" -o "$docx_file" 2>/dev/null; then
        log_success "[REPORT] DOCX report generated: $docx_file"
        return 0
    else
        log_warning "[REPORT] DOCX generation failed"
        return 1
    fi
}

# Main report generation function
function generate_full_report() {
    local targets_dir="$1"
    local output_dir="${2:-.}"
    local generate_docx="${3:-false}"
    
    log_info "[REPORT] Starting report generation..."
    
    local html_file="${output_dir}/report.html"
    local docx_file="${output_dir}/report.docx"
    
    # Generate HTML report
    generate_html_report "$targets_dir" "$html_file"
    
    # Generate DOCX if requested
    if [ "$generate_docx" = "true" ]; then
        generate_docx_report "$html_file" "$docx_file"
    fi
    
    log_success "[REPORT] Report generation complete"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📄 Reports Generated:"
    echo "   HTML: file://$(realpath "$html_file")"
    [ -f "$docx_file" ] && echo "   DOCX: $(realpath "$docx_file")"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Export functions
export -f generate_html_header generate_html_footer generate_executive_summary
export -f generate_target_section generate_html_report generate_docx_report
export -f generate_full_report
