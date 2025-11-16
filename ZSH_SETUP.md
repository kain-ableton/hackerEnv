# HackerEnv - Zsh Setup Complete ✅

## Aliases Added to ~/.zshrc

```zsh
alias hackerenv='cd ~/hackerEnv'
alias henv2='~/hackerEnv/hackerEnv2'
alias henv='~/hackerEnv/hackerEnv'
export PATH="$HOME/hackerEnv:$PATH"
```

---

## Activate Now

```bash
source ~/.zshrc
```

---

## Usage After Reload

### Navigate to HackerEnv
```bash
hackerenv              # Go to ~/hackerEnv directory
```

### Run from Anywhere
```bash
henv2 --help           # Run refactored version
henv2 -t 192.168.1.100 # Scan a target

henv --help            # Run original version
henv -t 192.168.1.100  # Original scan
```

### Run Without Alias (PATH added)
```bash
hackerEnv2 --help      # Works from any directory
hackerEnv -h           # Original works too
```

---

## Test It

```bash
# 1. Reload your shell
source ~/.zshrc

# 2. Try the alias
hackerenv              # Should cd to ~/hackerEnv

# 3. Try from another directory
cd ~
henv2 --version        # Should work from anywhere

# 4. Test PATH
cd /tmp
hackerEnv2 --help      # Should work
```

---

## What Was Added

1. **`hackerenv`** - Quick navigation to hackerEnv directory
2. **`henv2`** - Run refactored version from anywhere
3. **`henv`** - Run original version from anywhere
4. **PATH** - Both scripts accessible globally

---

## Zsh Completion (Optional)

For enhanced autocompletion, add to `~/.zshrc`:

```zsh
# HackerEnv completion
_hackerenv2() {
    local -a commands
    commands=(
        '-t:Target IP address'
        '-i:Network interface'
        '-s:Subnet mask'
        '-e:Aggressive mode'
        '--help:Show help'
        '--version:Show version'
        '--bruteforce:Enable bruteforce'
        '--no-auth:Disable authorization'
    )
    _describe 'command' commands
}

compdef _hackerenv2 hackerEnv2
compdef _hackerenv2 henv2
```

---

## Status

✅ Aliases configured  
✅ PATH updated  
✅ Ready to use  

**Next step:** Run `source ~/.zshrc` to activate!
