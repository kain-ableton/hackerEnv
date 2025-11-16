#!/bin/bash
# Test suite for HackerEnv v2.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

TEST_PASSED=0
TEST_FAILED=0

function assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    if [ "$expected" = "$actual" ]; then
        ((TEST_PASSED++))
        log_success "✓ $test_name"
    else
        ((TEST_FAILED++))
        log_error "✗ $test_name"
        log_error "  Expected: $expected"
        log_error "  Got: $actual"
    fi
}

function assert_true() {
    local command="$1"
    local test_name="$2"
    
    if eval "$command"; then
        ((TEST_PASSED++))
        log_success "✓ $test_name"
    else
        ((TEST_FAILED++))
        log_error "✗ $test_name"
    fi
}

function assert_false() {
    local command="$1"
    local test_name="$2"
    
    if ! eval "$command"; then
        ((TEST_PASSED++))
        log_success "✓ $test_name"
    else
        ((TEST_FAILED++))
        log_error "✗ $test_name"
    fi
}

function test_valid_ip() {
    log_info "Testing IP validation..."
    
    assert_true "valid_ip '192.168.1.1'" "Valid IP: 192.168.1.1"
    assert_true "valid_ip '10.0.0.1'" "Valid IP: 10.0.0.1"
    assert_true "valid_ip '172.16.0.1'" "Valid IP: 172.16.0.1"
    assert_true "valid_ip '127.0.0.1'" "Valid IP: 127.0.0.1"
    
    assert_false "valid_ip '999.999.999.999'" "Invalid IP: 999.999.999.999"
    assert_false "valid_ip '192.168.1'" "Invalid IP: 192.168.1"
    assert_false "valid_ip 'not.an.ip.addr'" "Invalid IP: not.an.ip.addr"
    assert_false "valid_ip '192.168.1.1; rm -rf /'" "Invalid IP with injection"
}

function test_sanitize_ip() {
    log_info "Testing IP sanitization..."
    
    local result=$(sanitize_ip "192.168.1.1")
    assert_equals "192.168.1.1" "$result" "Sanitize clean IP"
    
    result=$(sanitize_ip "192.168.1.1;rm -rf /")
    assert_equals "192.168.1.1" "$result" "Sanitize IP with command injection"
    
    result=$(sanitize_ip "192.168.1.1\$(whoami)")
    assert_equals "192.168.1.1" "$result" "Sanitize IP with command substitution"
}

function test_valid_cidr() {
    log_info "Testing CIDR validation..."
    
    assert_true "valid_cidr '192.168.1.0/24'" "Valid CIDR: 192.168.1.0/24"
    assert_true "valid_cidr '10.0.0.0/8'" "Valid CIDR: 10.0.0.0/8"
    assert_true "valid_cidr '172.16.0.0/16'" "Valid CIDR: 172.16.0.0/16"
    
    assert_false "valid_cidr '192.168.1.0/33'" "Invalid CIDR: mask > 32"
    assert_false "valid_cidr '192.168.1.0'" "Invalid CIDR: no mask"
    assert_false "valid_cidr '999.999.999.999/24'" "Invalid CIDR: bad IP"
}

function test_file_operations() {
    log_info "Testing file operations..."
    
    local test_dir="/tmp/hackerenv_test_$$"
    
    if safe_create_dir "$test_dir"; then
        assert_true "[ -d '$test_dir' ]" "Directory created"
    fi
    
    if safe_remove "$test_dir"; then
        assert_false "[ -d '$test_dir' ]" "Directory removed"
    fi
}

function test_config_loading() {
    log_info "Testing configuration loading..."
    
    local test_config="/tmp/test_config_$$.conf"
    cat > "$test_config" <<EOF
# Test configuration
test_key=test_value
another_key=123
EOF
    
    load_config "$test_config"
    
    assert_equals "test_value" "${CONFIG_TEST_KEY:-}" "Config value loaded"
    assert_equals "123" "${CONFIG_ANOTHER_KEY:-}" "Config numeric value loaded"
    
    rm -f "$test_config"
}

function run_all_tests() {
    log_info "Starting HackerEnv v2.0 Test Suite"
    echo ""
    
    test_valid_ip
    test_sanitize_ip
    test_valid_cidr
    test_file_operations
    test_config_loading
    
    echo ""
    log_info "================================"
    log_info "Test Results"
    log_info "================================"
    log_success "Passed: $TEST_PASSED"
    if [ $TEST_FAILED -gt 0 ]; then
        log_error "Failed: $TEST_FAILED"
        exit 1
    else
        log_success "Failed: $TEST_FAILED"
        log_success "All tests passed!"
        exit 0
    fi
}

# Run tests
run_all_tests
