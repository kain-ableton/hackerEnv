#!/bin/bash
# lib/version.sh - Version information and display
# Version: 2.0.1

set -euo pipefail

# Source utils for colors if not already loaded
if [ -z "${RED:-}" ]; then
    SCRIPT_DIR_VERSION="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR_VERSION}/lib/utils.sh"
fi

VERSION="2.0.1"
VERSION_DATE="2025-11-16"
BUILD="Enhanced"
GITHUB_REPO="abdulr7mann/hackerEnv"

function show_version_info() {
    cat << EOF

╔══════════════════════════════════════════════════════════════════╗
║                    HACKERENV VERSION INFO                        ║
╚══════════════════════════════════════════════════════════════════╝

  ${BOLD}Version:${RESET}        $VERSION ($BUILD)
  ${BOLD}Release Date:${RESET}   $VERSION_DATE
  ${BOLD}Repository:${RESET}     https://github.com/$GITHUB_REPO

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${CYAN}📦 Core Features:${RESET}
    • 7 Specialized Toolchains
    • Metasploit Framework Integration
    • Hydra Brute Force Module
    • Smart LHOST Auto-Detection (tun0 priority)
    • Statistics & Risk Assessment
    • Post-Exploitation Analysis
    • HTML/DOCX Report Generation
    • Verbosity Control System

  ${CYAN}🔧 Scan Modes:${RESET}
    • Quick, Normal, Full, Stealth, UDP

  ${CYAN}🎯 Exploit Modules:${RESET}
    • SSH Exploitation
    • Metasploit (EternalBlue, SMB, FTP, HTTP)
    • Hydra (SSH, FTP, Telnet, SMB, MySQL)

  ${CYAN}📊 Analytics:${RESET}
    • JSON Statistics Export
    • Risk Scoring Algorithm
    • Attack Surface Analysis
    • Credential Extraction

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${CYAN}📝 Installed Components:${RESET}
EOF

    # Check installed components
    local components=(
        "nmap:Port Scanner"
        "msfconsole:Metasploit Framework"
        "hydra:Password Cracker"
        "whatweb:Web Scanner"
        "nikto:Web Vulnerability Scanner"
        "sqlmap:SQL Injection Tool"
        "enum4linux:SMB Enumerator"
        "dnsrecon:DNS Reconnaissance"
    )
    
    for comp in "${components[@]}"; do
        local cmd="${comp%%:*}"
        local name="${comp##*:}"
        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$(get_tool_version "$cmd")
            echo -e "    ${GREEN}✓${RESET} $name: $ver"
        else
            echo -e "    ${YELLOW}✗${RESET} $name: Not installed"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ${CYAN}📚 Documentation:${RESET}"
    echo "    • README.md"
    echo "    • NEW_FEATURES_V2.md"
    echo "    • ENHANCED_FEATURES.md"
    echo "    • LHOST_AUTO_DETECTION.md"
    echo "    • COMPLETE_FEATURE_MATRIX.md"
    echo ""
    echo "  ${CYAN}🌐 Links:${RESET}"
    echo "    • GitHub: https://github.com/$GITHUB_REPO"
    echo "    • Issues: https://github.com/$GITHUB_REPO/issues"
    echo ""
}

function get_tool_version() {
    local tool="$1"
    local version="unknown"
    
    case "$tool" in
        nmap)
            version=$(nmap --version 2>/dev/null | head -1 | awk '{print $3}')
            ;;
        msfconsole)
            version=$(msfconsole --version 2>/dev/null | head -1 | awk '{print $2}')
            ;;
        hydra)
            version=$(hydra -h 2>&1 | grep "Hydra v" | awk '{print $3}')
            ;;
        *)
            version=$(command -v "$tool" &>/dev/null && echo "installed" || echo "not found")
            ;;
    esac
    
    echo "$version"
}

export VERSION VERSION_DATE BUILD
export -f show_version_info get_tool_version
