# HackerEnv Scan Modes

HackerEnv v2 now supports multiple nmap scan modes for different scenarios.

## Available Modes

### 1. Quick Mode (`-m quick`)
- **Use case**: Fast reconnaissance, initial discovery
- **Nmap options**: `-T4 -F --top-ports 100`
- **Speed**: Very fast (seconds)
- **Coverage**: Top 100 most common ports
- **Example**: `./hackerEnv2 -t 192.168.1.100 -m quick`

### 2. Normal Mode (`-m normal` or default)
- **Use case**: Standard security assessment
- **Nmap options**: `-sV -T4 -A -O`
- **Speed**: Moderate (1-5 minutes per host)
- **Coverage**: Default 1000 ports + service detection + OS detection
- **Example**: `./hackerEnv2 -t 192.168.1.100`

### 3. Full Mode (`-m full`)
- **Use case**: Comprehensive security audit
- **Nmap options**: `-sV -sC -T4 -p- -A -O`
- **Speed**: Slow (10-60+ minutes per host)
- **Coverage**: All 65535 TCP ports + scripts + service detection
- **Example**: `./hackerEnv2 -t 192.168.1.100 -m full`

### 4. Stealth Mode (`-m stealth`)
- **Use case**: Avoiding IDS/IPS detection
- **Nmap options**: `-sS -T2 -f --data-length 25 -D RND:5`
- **Speed**: Very slow (careful timing)
- **Coverage**: SYN scan with fragmentation and decoys
- **Example**: `./hackerEnv2 -t 192.168.1.100 -m stealth`

### 5. UDP Mode (`-m udp`)
- **Use case**: Scanning UDP services (DNS, SNMP, etc.)
- **Nmap options**: `-sU -sV --top-ports 100 -T4`
- **Speed**: Slow (UDP is inherently slower)
- **Coverage**: Top 100 UDP ports
- **Example**: `./hackerEnv2 -t 192.168.1.100 -m udp`

## Combining Options

### Aggressive Mode Override
Adding `-e` or `--aggressive` flag will override any mode and add:
- `-p-` (all ports)
- `-T5` (insane timing)

**Example**: `./hackerEnv2 -t 192.168.1.100 -m quick --aggressive`

### Network Scanning
All modes work with CIDR ranges:

```bash
# Quick scan of entire subnet
./hackerEnv2 -t 192.168.1.0/24 -m quick

# Stealth scan of network
./hackerEnv2 -t 10.0.0.0/24 -m stealth

# Full comprehensive audit
./hackerEnv2 -t 192.168.1.0/24 -m full
```

## Mode Selection Guide

| Scenario | Recommended Mode |
|----------|-----------------|
| Initial network discovery | `quick` |
| Standard penetration test | `normal` |
| Comprehensive security audit | `full` |
| Evading detection | `stealth` |
| Finding UDP services | `udp` |
| Time-critical assessment | `quick` |
| Red team engagement | `stealth` |

## Performance Comparison

Approximate scan times for a single host:

| Mode | Scan Time | Ports Scanned |
|------|-----------|---------------|
| Quick | 5-30 seconds | 100 TCP |
| Normal | 1-5 minutes | 1000 TCP |
| Full | 10-60 minutes | 65535 TCP |
| Stealth | 15-90 minutes | 1000 TCP |
| UDP | 5-30 minutes | 100 UDP |

*Times vary based on network conditions, host responsiveness, and firewall configurations*

## Tips

1. **Start with quick mode** for initial reconnaissance
2. **Use stealth mode** when testing production systems during business hours
3. **Full mode** is best run overnight for large networks
4. **UDP mode** is separate from TCP - run both for complete coverage
5. **Aggressive mode** should only be used when speed is critical and detection is not a concern

## Error Handling

If a scan mode fails or times out:
- Check network connectivity
- Verify target is reachable
- Try a less intensive mode first
- Check firewall rules

For more information, see the main README.md or run `./hackerEnv2 --help`
