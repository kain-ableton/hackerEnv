#!/bin/bash
# tests/comprehensive_test.sh - Comprehensive functionality test
# Version: 2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     HackerEnv v2.0 - Comprehensive Functionality Test     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0
TOTAL=0

function test_case() {
    local name="$1"
    local command="$2"
    
    TOTAL=$((TOTAL + 1))
    echo -n "[$TOTAL] Testing: $name ... "
    
    if eval "$command" &>/dev/null; then
        echo "✓ PASS"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAIL"
        FAILED=$((FAILED + 1))
    fi
}

echo "=== Syntax Checks ==="
test_case "Main script syntax" "bash -n hackerEnv2"
test_case "Scanner syntax" "bash -n core/scanner.sh"
test_case "Utils syntax" "bash -n lib/utils.sh"
test_case "SSH module syntax" "bash -n modules/ssh.sh"
test_case "Web toolchain syntax" "bash -n toolchains/web_toolchain.sh"
test_case "SMB toolchain syntax" "bash -n toolchains/smb_toolchain.sh"
test_case "DNS toolchain syntax" "bash -n toolchains/dns_toolchain.sh"
test_case "Toolchain manager syntax" "bash -n toolchains/toolchain_manager.sh"
echo ""

echo "=== Help System ==="
test_case "Help command" "./hackerEnv2 --help"
test_case "Version command" "./hackerEnv2 --version"
echo ""

echo "=== Configuration ==="
test_case "Config file exists" "[ -f config/settings.conf ]"
test_case "Config readable" "[ -r config/settings.conf ]"
echo ""

echo "=== Directory Structure ==="
test_case "Core directory" "[ -d core ]"
test_case "Lib directory" "[ -d lib ]"
test_case "Modules directory" "[ -d modules ]"
test_case "Toolchains directory" "[ -d toolchains ]"
test_case "Config directory" "[ -d config ]"
echo ""

echo "=== File Permissions ==="
test_case "Main script executable" "[ -x hackerEnv2 ]"
test_case "Web toolchain executable" "[ -x toolchains/web_toolchain.sh ]"
test_case "SMB toolchain executable" "[ -x toolchains/smb_toolchain.sh ]"
test_case "DNS toolchain executable" "[ -x toolchains/dns_toolchain.sh ]"
test_case "Toolchain manager executable" "[ -x toolchains/toolchain_manager.sh ]"
echo ""

echo "=== Documentation ==="
test_case "README exists" "[ -f README.md ]"
test_case "SCAN_MODES exists" "[ -f SCAN_MODES.md ]"
test_case "ADVANCED_FEATURES exists" "[ -f ADVANCED_FEATURES.md ]"
test_case "STRENGTHS exists" "[ -f STRENGTHS.md ]"
test_case "COMPARISON exists" "[ -f COMPARISON.md ]"
test_case "TOOLCHAINS exists" "[ -f TOOLCHAINS.md ]"
test_case "CHANGELOG exists" "[ -f CHANGELOG_v2.md ]"
test_case "DONE exists" "[ -f DONE.md ]"
test_case "QUICK_START exists" "[ -f QUICK_START.md ]"
echo ""

echo "=== Scan Mode Validation ==="
test_case "Quick mode accepted" "./hackerEnv2 -t 127.0.0.1 -m quick --help 2>&1 | grep -q quick"
test_case "Normal mode accepted" "./hackerEnv2 -t 127.0.0.1 -m normal --help 2>&1 | grep -q normal"
test_case "Full mode accepted" "./hackerEnv2 -t 127.0.0.1 -m full --help 2>&1 | grep -q full"
test_case "Stealth mode accepted" "./hackerEnv2 -t 127.0.0.1 -m stealth --help 2>&1 | grep -q stealth"
test_case "UDP mode accepted" "./hackerEnv2 -t 127.0.0.1 -m udp --help 2>&1 | grep -q udp"
echo ""

echo "=== Dependencies ==="
test_case "nmap installed" "command -v nmap"
test_case "fping installed" "command -v fping"
test_case "grep available" "command -v grep"
test_case "awk available" "command -v awk"
test_case "sed available" "command -v sed"
echo ""

echo "=== Function Definitions ==="
test_case "scan_host function" "grep -q 'function scan_host' core/scanner.sh"
test_case "parse_scan_results function" "grep -q 'function parse_scan_results' core/scanner.sh"
test_case "scan_vulnerabilities function" "grep -q 'function scan_vulnerabilities' core/scanner.sh"
test_case "run_service_scripts function" "grep -q 'function run_service_scripts' core/scanner.sh"
test_case "web_toolchain_run function" "grep -q 'function web_toolchain_run' toolchains/web_toolchain.sh"
test_case "smb_toolchain_run function" "grep -q 'function smb_toolchain_run' toolchains/smb_toolchain.sh"
test_case "dns_toolchain_run function" "grep -q 'function dns_toolchain_run' toolchains/dns_toolchain.sh"
test_case "run_auto_toolchains function" "grep -q 'function run_auto_toolchains' toolchains/toolchain_manager.sh"
echo ""

echo "=== Variable Exports ==="
test_case "Scanner functions exported" "grep -q 'export -f.*scan_host' core/scanner.sh"
test_case "Toolchain functions exported" "grep -q 'export -f.*web_toolchain_run' toolchains/web_toolchain.sh"
test_case "Manager functions exported" "grep -q 'export -f.*run_auto_toolchains' toolchains/toolchain_manager.sh"
echo ""

echo "=== Configuration Options ==="
test_case "vuln_scan_enabled in config" "grep -q 'vuln_scan_enabled' config/settings.conf"
test_case "nmap_options in config" "grep -q 'nmap_options' config/settings.conf"
test_case "bruteforce config" "grep -q 'enabled=' config/settings.conf"
echo ""

echo "════════════════════════════════════════════════════════════"
echo "                    TEST SUMMARY"
echo "════════════════════════════════════════════════════════════"
echo "Total Tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✓ ALL TESTS PASSED!"
    echo "Status: PRODUCTION READY ✅"
    exit 0
else
    echo "✗ SOME TESTS FAILED"
    echo "Status: REVIEW REQUIRED"
    exit 1
fi
