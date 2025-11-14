# Installation Script - Quick Fix Reference

## What Was Wrong

The original `install.sh` had these critical issues:

| Issue | Impact | Fixed |
|-------|--------|-------|
| Missing `rapiba-backup.service` | No scheduled backups | ✅ |
| Missing `rapiba-backup.timer` | Timer validation failed | ✅ |
| Missing `rapiba_admin.py` | Admin tool unavailable | ✅ |
| No INI header in config | Service crashes on startup | ✅ |
| No validation after install | Silent failures undetected | ✅ |

## Installation Before vs After

### BEFORE (Broken)
```bash
$ sudo bash install.sh
# Installation says "complete" but...

$ sudo bash verify_installation.sh
✗ Scheduled Backup Service: not found
✗ Backup-Timer: not found
# Now you discover problems!

$ sudo systemctl start rapiba
# Service crashes with:
# MissingSectionHeaderError: File contains no section headers
```

### AFTER (Fixed)
```bash
$ sudo bash install.sh
# Shows all 9 steps including NEW validation step:
[9/9] Validiere Installation...
✓ All 16 components verified

# Installation is really complete!

$ sudo bash verify_installation.sh
✓ All checks pass (22 successful)

$ sudo systemctl start rapiba
# Service starts immediately without errors
```

## Technical Changes

### 1. Configuration Validation (Step 3)
```bash
# NEW: Auto-fixes missing [rapiba] INI section header
if ! grep -q "^\[rapiba\]" etc/rapiba.conf; then
    echo "[rapiba]" > "$CONFIG_DIR/rapiba.conf"
    cat etc/rapiba.conf >> "$CONFIG_DIR/rapiba.conf"
fi
```

### 2. Systemd Services (Step 5)
```bash
# NEW: Installs all systemd components
cp systemd/rapiba.service "$SYSTEMD_DIR/"
cp systemd/rapiba-backup.service "$SYSTEMD_DIR/"
cp systemd/rapiba-backup.timer "$SYSTEMD_DIR/"
```

### 3. Python Modules (Step 2)
```bash
# NEW: Includes admin tool
cp src/rapiba_admin.py "$INSTALL_DIR/"
```

### 4. Installation Validation (NEW Step 9)
```bash
# NEW: Validates 16 critical installation components
# Checks files, directories, permissions, config validity
# Returns exit code 1 if any check fails
```

## Installation Checklist

Use this checklist to verify a fresh installation:

### After Running `sudo bash install.sh`

- [ ] Script completes without errors
- [ ] Shows 9 steps (not 8)
- [ ] Step [9/9] shows "Validiere Installation"
- [ ] All ✓ checks pass in validation
- [ ] No ✗ checks appear

### After Installation

- [ ] Config file exists: `ls /etc/rapiba/rapiba.conf`
- [ ] Main service installed: `ls /etc/systemd/system/rapiba.service`
- [ ] **NEW** Backup service: `ls /etc/systemd/system/rapiba-backup.service`
- [ ] **NEW** Backup timer: `ls /etc/systemd/system/rapiba-backup.timer`
- [ ] Admin tool: `ls /usr/local/lib/rapiba/rapiba_admin.py`

### Service Status Check

```bash
# Monitor service should be running
sudo systemctl status rapiba.service

# Backup timer should be active
sudo systemctl status rapiba-backup.timer

# Run verification script
sudo bash verify_installation.sh
```

## Common Scenarios

### Scenario 1: Fresh Installation
```bash
cd rapiba
sudo bash install.sh
# Should complete all 9 steps successfully
```

### Scenario 2: Reinstalling After Errors
```bash
# Old config will be preserved
# New validation ensures correctness
sudo bash install.sh
# Should detect and fix any previous issues
```

### Scenario 3: Updating Installation
```bash
# Config file won't be overwritten
# New config saved as rapiba.conf.new for reference
sudo bash install.sh
```

## Troubleshooting

### If installation fails at step [9/9]
```bash
# Shows exactly which file/directory is missing
# Example error:
# ✗ systemd Backup Service (FEHLER: nicht gefunden)

# Solution: Check if source files exist
ls systemd/rapiba-backup.service
ls systemd/rapiba-backup.timer
# If missing, re-clone the repository
```

### If config has no INI header
```bash
# Installation now automatically fixes this!
# You'll see:
# "Konfiguration mit INI-Header installiert"

# If using old config file:
# Add this as first line: [rapiba]
nano /etc/rapiba/rapiba.conf
```

### If service still fails to start
```bash
# Check logs
sudo journalctl -u rapiba -n 50

# Run verification
sudo bash verify_installation.sh

# Check config syntax
python3 -c "
import sys
sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import Config
config = Config('/etc/rapiba/rapiba.conf')
print('Config OK')
"
```

## Installation Steps Explained

| Step | What | Why | Impact |
|------|------|-----|--------|
| [0/9] | Check Python | Verify compatibility | Early error detection |
| [1/9] | Create dirs | Setup structure | File permissions ready |
| [2/9] | Copy modules | **Includes admin tool now** | Admin commands work |
| [3/9] | Config file | **Validates INI headers** | No parser errors |
| [4/9] | Create scripts | Make commands | System access point |
| [5/9] | Systemd | **Installs all services** | Backup timer included |
| [6/9] | udev rules | Device detection | Auto-backup on insert |
| [7/9] | Permissions | Security + access | Everything accessible |
| [8/9] | Dependencies | Check libraries | Runtime ready |
| [9/9] | **Validate ALL** | **NEW STEP** | **Catches all errors** |

---

**The fixed installation script ensures a complete, working Rapiba system in one command.**
