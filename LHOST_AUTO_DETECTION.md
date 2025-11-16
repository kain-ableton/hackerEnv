# LHOST Auto-Detection for Metasploit

## Overview

The Metasploit module now automatically detects the best LHOST (Local Host) IP address for reverse connections, with intelligent prioritization of VPN interfaces commonly used in penetration testing.

## Feature Details

### Function: `metasploit_get_lhost()`

**Location:** `modules/metasploit.sh`

**Purpose:** Automatically detect and return the best IP address for Metasploit LHOST parameter

### Detection Priority

The function checks interfaces in the following order:

1. **tun0** - OpenVPN/Most common VPN (Hack The Box, TryHackMe, etc.)
2. **tun1** - Alternative VPN tunnel
3. **tap0** - TAP-mode VPN
4. **Default Route** - Interface used for default routing
5. **Fallback** - First non-loopback interface

### Implementation

```bash
function metasploit_get_lhost() {
    # Priority 1: tun0 (OpenVPN/VPN)
    if ip addr show tun0 &>/dev/null; then
        lhost=$(ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
        if [ -n "$lhost" ]; then
            log_info "[$MODULE_NAME] Using tun0 interface: $lhost"
            echo "$lhost"
            return 0
        fi
    fi
    
    # Priority 2-5: Check tun1, tap0, default route, fallback
    # ...
}
```

## Usage

### Automatic (Recommended)

```bash
# Simply run the scan - LHOST is auto-detected
./hackerEnv2 -t 192.168.1.100 --bruteforce

# Output will show:
# [INFO] [METASPLOIT] Using tun0 interface: 10.10.15.57
```

### Manual Override (Optional)

If you need to override the auto-detection:

```bash
# Edit hackerEnv2 and pass specific LHOST:
metasploit_module_main "$target" "$target_dir" "192.168.1.100"
```

## Benefits

### For Penetration Testers

1. **No Configuration Needed** - Works out of the box with HTB, THM, and other VPN labs
2. **Correct Interface** - Always uses VPN tunnel for reverse shells
3. **Automatic Fallback** - Works even without VPN
4. **Clear Logging** - Shows which interface and IP is being used

### For CTF/Lab Environments

- ✅ Hack The Box (HTB) - Detects tun0 automatically
- ✅ TryHackMe (THM) - Detects tun0 automatically  
- ✅ OffSec Labs - Detects tun0 automatically
- ✅ Local Testing - Falls back to default interface
- ✅ Multi-VPN - Handles tun0, tun1, tap0

## Example Output

### With VPN (tun0) Active

```
[INFO] [METASPLOIT] Starting Metasploit module for: 10.10.10.100
[INFO] [METASPLOIT] Using tun0 interface: 10.10.15.57
[INFO] [METASPLOIT] Local host (LHOST): 10.10.15.57
[INFO] [METASPLOIT] SMB service detected - preparing exploits
```

### Without VPN (Fallback)

```
[INFO] [METASPLOIT] Starting Metasploit module for: 192.168.1.100
[INFO] [METASPLOIT] Using default route interface: 192.168.1.50
[INFO] [METASPLOIT] Local host (LHOST): 192.168.1.50
```

## Testing

### Verify Detection

```bash
cd /home/k/hackerEnv
source lib/utils.sh
source modules/metasploit.sh

# Test the function
metasploit_get_lhost

# Expected output:
# [INFO] [METASPLOIT] Using tun0 interface: 10.10.15.57
# 10.10.15.57
```

### Check Current Interfaces

```bash
# See what interfaces are available
ip addr show | grep -E "inet.*tun|inet.*tap"

# Check tun0 specifically
ip addr show tun0 2>/dev/null || echo "tun0 not present"
```

## Integration

### Called Automatically

The function is called automatically by `metasploit_module_main()`:

```bash
function metasploit_module_main() {
    local target="$1"
    local output_dir="$2"
    local lhost="${3:-}"
    
    # Auto-detect LHOST if not provided
    if [ -z "$lhost" ]; then
        lhost=$(metasploit_get_lhost)
    fi
    
    # ... rest of module
}
```

### In hackerEnv2

```bash
# No LHOST parameter needed - auto-detects
metasploit_module_main "$target" "$target_dir"
```

## Troubleshooting

### Issue: Wrong Interface Selected

**Solution:** Check interface priority and ensure VPN is connected

```bash
# Verify VPN connection
ip addr show tun0

# If tun0 exists but wrong IP, check:
ip -4 addr show tun0 | grep inet
```

### Issue: No IP Detected

**Solution:** Check network configuration

```bash
# Check all interfaces
ip addr show

# Check default route
ip route get 1
```

### Issue: Firewall Blocking

**Solution:** Ensure firewall allows traffic on LHOST interface

```bash
# Allow traffic on tun0
sudo iptables -A INPUT -i tun0 -j ACCEPT
sudo iptables -A OUTPUT -o tun0 -j ACCEPT
```

## Technical Notes

### IP Extraction

Uses `grep -oP` with Perl regex for reliable IP extraction:

```bash
ip -4 addr show tun0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

### Error Handling

- Returns `127.0.0.1` if all detection fails
- Logs warnings for fallback scenarios
- Never fails silently

### Logging

All detection steps are logged:

```
log_info "[$MODULE_NAME] Using tun0 interface: $lhost"
log_warning "[$MODULE_NAME] Using fallback interface: $lhost"
log_error "[$MODULE_NAME] Could not determine LHOST"
```

## Compatibility

### Operating Systems

- ✅ Linux (Ubuntu, Debian, Kali, Parrot)
- ✅ Other Unix-like systems with `ip` command

### VPN Types

- ✅ OpenVPN (tun)
- ✅ Wireguard (typically wg0, but can create tun0)
- ✅ TAP VPN (tap0)
- ✅ Multiple simultaneous VPNs

## Version History

**v2.0.1** (2025-11-16)
- ✅ Added automatic LHOST detection
- ✅ Priority-based interface selection
- ✅ VPN tunnel prioritization (tun0, tun1, tap0)
- ✅ Intelligent fallback mechanism
- ✅ Comprehensive logging

## See Also

- `modules/metasploit.sh` - Full Metasploit module implementation
- `ENHANCED_FEATURES.md` - Complete feature enhancements
- `INTEGRATION_COMPLETE.md` - Full integration report

---

**Status:** ✅ Production Ready  
**Tested:** ✅ With tun0 (10.10.15.57)  
**Result:** ✅ Working correctly
