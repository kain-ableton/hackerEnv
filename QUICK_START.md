# HackerEnv v2.0 - Quick Start Guide

## Installation

```bash
cd /home/k/hackerEnv
chmod +x hackerEnv2
```

## Basic Usage

```bash
# Quick scan
./hackerEnv2 -t 192.168.1.100 -m quick

# Standard scan
./hackerEnv2 -t 192.168.1.100

# With toolchains
./hackerEnv2 -t 192.168.1.100 --toolchain auto
```

## Common Commands

### Scanning
| Command | Description |
|---------|-------------|
| `-m quick` | Fast scan (top 100 ports) |
| `-m normal` | Standard scan (default) |
| `-m full` | All ports scan |
| `-m stealth` | Evasive scan |
| `-m udp` | UDP scan |

### Toolchains
| Command | Description |
|---------|-------------|
| `--toolchain auto` | Auto-detect services |
| `--toolchain web` | Web assessment |
| `--toolchain smb` | SMB enumeration |
| `--toolchain dns` | DNS reconnaissance |
| `--toolchain all` | Run all toolchains |
| `--no-toolchains` | Skip toolchains |

### Options
| Command | Description |
|---------|-------------|
| `--no-vuln-scan` | Skip vulnerability scanning |
| `--bruteforce` | Enable password attacks |
| `--aggressive` | Aggressive mode |
| `-e` | Aggressive mode (short) |

## Examples

```bash
# Quick network scan
./hackerEnv2 -t 192.168.1.0/24 -m quick

# Full web assessment
./hackerEnv2 -t example.com --toolchain web

# Stealth scan with all toolchains
./hackerEnv2 -t 192.168.1.100 -m stealth --toolchain all

# Aggressive full scan
./hackerEnv2 -t 192.168.1.100 -m full --aggressive
```

## Output Locations

```
targets/<IP>/
├── nmap_scan.xml          # Main scan results
├── services.txt           # Detected services
├── web_toolchain/         # Web assessment results
├── smb_toolchain/         # SMB results
├── dns_toolchain/         # DNS results
└── scan_summary.txt       # Summary report
```

## Help

```bash
./hackerEnv2 --help
```

## Documentation

- SCAN_MODES.md - Detailed scan modes
- TOOLCHAINS.md - Toolchain guide
- ADVANCED_FEATURES.md - Advanced features
- DONE.md - Complete feature list
