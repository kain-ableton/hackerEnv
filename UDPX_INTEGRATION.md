# UDPX Integration - UDP Service Discovery

## Overview

HackerEnv now includes **UDPX** integration - a fast, lightweight UDP scanner written in Go that supports discovery of 45+ services with single-packet probes.

## What is UDPX?

UDPX is a specialized UDP scanner that:
- ✅ **Fast** - Scan /16 networks in ~20 seconds
- ✅ **Lightweight** - No libpcap or dependencies required
- ✅ **Cross-platform** - Works on Linux, macOS, Windows
- ✅ **Accurate** - Uses protocol-specific packets for service detection
- ✅ **Comprehensive** - Supports 45+ UDP services

## Installation

### Option 1: Via Go (Recommended)
```bash
# Install Go if not already installed
sudo apt install golang-go -y

# Install UDPX
go install github.com/nullt3r/udpx/cmd/udpx@latest

# Add to PATH
export PATH=$PATH:$HOME/go/bin
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
```

### Option 2: Automatic Installation
HackerEnv can install UDPX automatically on first use.

### Option 3: Manual Build
```bash
git clone https://github.com/nullt3r/udpx
cd udpx
go build ./cmd/udpx
sudo mv udpx /usr/local/bin/
```

## Usage

### Enable UDP Scanning

```bash
# Scan with UDP discovery enabled
./hackerEnv2 -t 192.168.1.100 --udp-scan

# Verbose UDP scan
./hackerEnv2 -t 192.168.1.0/24 --udp-scan -vv

# UDP scan with custom concurrency
UDPX_CONCURRENCY=128 ./hackerEnv2 -t TARGET --udp-scan
```

### Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--udp-scan` | Enable UDP scanning with UDPX | Disabled |
| `-vv` | Show detailed UDP scan output | Normal |
| `-t TARGET` | Target IP/CIDR for scanning | Required |

### Environment Variables

```bash
# Customize UDPX behavior
export UDPX_DEFAULT_TIMEOUT=1000      # Timeout in ms (default: 500)
export UDPX_DEFAULT_CONCURRENCY=128   # Concurrent connections (default: 32)
```

## Supported Services (45+)

### High-Value Services
- **IPMI** - Intelligent Platform Management Interface
- **SNMP** (v1/v2/v3) - Network management
- **IKE** - Internet Key Exchange (VPN)
- **Kerberos** - Authentication protocol
- **LDAP** - Directory services
- **OpenVPN** - VPN service
- **TFTP** - Trivial File Transfer Protocol

### Additional Services
- ARD, Bacnet, Chargen, Citrix, CoAP
- DNS, MDNS, Memcache, MSSQL
- NetBIOS, NTP, NTP Monlist
- Portmap, RDP, SIP
- SSDP, UPnP, Ubiquiti Discovery
- WSD, XDMCP, and more...

Complete list in `modules/udpx.sh`

## Output

### Directory Structure
```
targets/192.168.1.100/
├── udpx/
│   ├── udpx_scan.jsonl           # Raw JSONL results
│   ├── udpx_summary.txt           # Human-readable summary
│   ├── udpx_output.log            # Scan output
│   └── udpx_nmap_format.txt       # Nmap-compatible format
```

### JSONL Format
```json
{"address":"192.168.1.100","hostname":"target.local","port":161,"service":"snmp","response_data":"..."}
{"address":"192.168.1.100","port":123,"service":"ntp","response_data":"..."}
```

### Summary Format
```
╔════════════════════════════════════════════════════════════════╗
║                    UDPX UDP SCAN SUMMARY                       ║
╚════════════════════════════════════════════════════════════════╝

Total Services Found: 5

Services Discovered:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  192.168.1.100    161     snmp            
  192.168.1.100    123     ntp             
  192.168.1.100    53      dns             

Service Statistics:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  snmp                   2
  ntp                    1
  dns                    1
```

## Integration Features

### 1. Automatic Interesting Service Detection
UDPX automatically highlights high-value services:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚠️  INTERESTING UDP SERVICES FOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ⚡ IPMI - 192.168.1.50:623
  ⚡ SNMP1 - 192.168.1.100:161
  ⚡ IKE - 192.168.1.1:500
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 2. Nmap Format Export
Results are exported in Nmap-compatible format for integration:
```
192.168.1.100:161 open udp snmp
192.168.1.100:123 open udp ntp
192.168.1.100:53 open udp dns
```

### 3. Statistics Integration
UDP services are included in final statistics and reports.

### 4. Workflow Integration
UDP scanning happens after TCP port scanning and before service-specific scripts.

## Examples

### Basic UDP Scan
```bash
./hackerEnv2 -t 192.168.1.100 --udp-scan
```

### Network-Wide UDP Discovery
```bash
./hackerEnv2 -t 192.168.1.0/24 --udp-scan -c 128
```

### Complete Scan with Reports
```bash
./hackerEnv2 -t TARGET --udp-scan -oA -vv
```

### UDP + Exploitation
```bash
./hackerEnv2 -t TARGET --udp-scan --bruteforce -oA
```

## Performance Tuning

### Fast Scan (Single Target)
```bash
# Default settings work well
./hackerEnv2 -t 192.168.1.100 --udp-scan
```

### Network Scan (Multiple Targets)
```bash
# Increase concurrency
export UDPX_DEFAULT_CONCURRENCY=128
./hackerEnv2 -t 192.168.1.0/24 --udp-scan
```

### Slow/Unstable Networks
```bash
# Increase timeout and reduce concurrency
export UDPX_DEFAULT_TIMEOUT=1000
export UDPX_DEFAULT_CONCURRENCY=16
./hackerEnv2 -t TARGET --udp-scan
```

### Aggressive Scan
```bash
# Maximum performance (use with caution)
export UDPX_DEFAULT_CONCURRENCY=256
export UDPX_DEFAULT_TIMEOUT=300
./hackerEnv2 -t TARGET --udp-scan -e
```

## Technical Details

### How It Works
1. UDPX sends protocol-specific UDP packets to each service/port
2. Waits for response within timeout (default 500ms)
3. If response received, service is confirmed open
4. Results stored in JSONL format
5. Summary generated and displayed

### Single-Packet Approach
Unlike traditional UDP scanning:
- ❌ **Traditional**: Send 0-byte packets, wait for ICMP unreachable
- ✅ **UDPX**: Send protocol-specific packets, get actual responses

### Advantages
- More accurate service detection
- Fewer false positives
- Protocol identification included
- Faster than traditional methods

## Security Notes

### Why UDP Scanning?

UDP services are often overlooked but can provide:
- **SNMP** - Network configuration and credentials
- **IPMI** - Out-of-band management access
- **IKE** - VPN configuration disclosure
- **Memcache** - Data exposure
- **DNS** - Zone transfers
- **NTP** - Time-based attacks

### Common Vulnerabilities
- **SNMP** - Default community strings (public/private)
- **IPMI** - Cipher zero authentication bypass
- **Memcache** - Unprotected memcached instances
- **DNS** - Zone transfer vulnerabilities
- **NTP** - Amplification attacks

## Troubleshooting

### UDPX Not Found
```bash
# Check if installed
which udpx

# Check Go bin path
ls $HOME/go/bin/udpx

# Add to PATH
export PATH=$PATH:$HOME/go/bin
```

### No Results
```bash
# Try increased timeout
export UDPX_DEFAULT_TIMEOUT=1000

# Check network connectivity
ping -c 1 TARGET

# Run with verbose mode
./hackerEnv2 -t TARGET --udp-scan -vvv
```

### Slow Scanning
```bash
# Increase concurrency
export UDPX_DEFAULT_CONCURRENCY=128

# Reduce timeout
export UDPX_DEFAULT_TIMEOUT=300
```

### Go Not Installed
```bash
# Install Go on Ubuntu/Debian
sudo apt update
sudo apt install golang-go -y

# Install Go on other systems
# Visit: https://go.dev/doc/install
```

## Module Functions

Available functions in `modules/udpx.sh`:

```bash
check_udpx_installed()              # Check if UDPX is available
install_udpx()                      # Install UDPX via Go
udpx_scan_target()                  # Scan target with UDPX
udpx_scan_specific_service()        # Scan for specific service
udpx_generate_summary()             # Generate scan summary
udpx_parse_results()                # Parse JSONL results
udpx_check_interesting_services()   # Highlight interesting services
udpx_export_to_nmap_format()        # Export to Nmap format
udpx_show_supported_services()      # List all supported services
```

## References

- **UDPX GitHub**: https://github.com/nullt3r/udpx
- **Original Author**: @nullt3r
- **License**: MIT

## Credits

UDPX is developed by nullt3r and inspired by:
- Nmap
- UDP Hunter
- ZGrab2
- ZMap

Integration into HackerEnv: 2025-11-16

---

**Status**: Production Ready  
**Version**: Added in HackerEnv v2.0.1  
**Compatibility**: All scan modes
