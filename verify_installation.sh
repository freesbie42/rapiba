#!/bin/bash
# Rapiba Verification Script - Prüft ob alles korrekt installiert ist

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (nicht gefunden)"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_dir() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $dir (nicht gefunden)"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_command() {
    local cmd=$1
    local description=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version=$("$cmd" --version 2>/dev/null | head -1 || echo "")
        echo -e "${GREEN}✓${NC} $description: $cmd $version"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $cmd (nicht installiert)"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_python_module() {
    local module=$1
    local description=$2
    
    if python3 -c "import $module" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $description: $module"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠${NC} $description: $module (optional)"
        ((CHECKS_WARNING++))
        return 1
    fi
}

check_permissions() {
    local file=$1
    local expected_mode=$2
    local description=$3
    
    if [ -e "$file" ]; then
        local mode=$(stat -c %a "$file" 2>/dev/null || stat -f %OLp "$file" 2>/dev/null | tail -c 4)
        if [ "$mode" = "$expected_mode" ]; then
            echo -e "${GREEN}✓${NC} Berechtigungen $description: $mode"
            ((CHECKS_PASSED++))
        else
            echo -e "${YELLOW}⚠${NC} Berechtigungen $description: $mode (erwartet: $expected_mode)"
            ((CHECKS_WARNING++))
        fi
    fi
}

check_service_status() {
    local service=$1
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Service läuft: $service"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Service läuft nicht: $service"
        ((CHECKS_WARNING++))
    fi
}

# Header
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Rapiba Installation Verification${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

# Python & Requirements
echo -e "${BLUE}[1] Python & Dependencies${NC}"
check_command "python3" "Python 3"

# Prüfe Python Version
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    if [ "$(printf '%s\n' "3.6" "$PYTHON_VERSION" | sort -V | head -n1)" = "3.6" ]; then
        echo -e "${GREEN}✓${NC} Python Version OK: $PYTHON_VERSION (minimum 3.6 erforderlich)"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} Python Version zu alt: $PYTHON_VERSION (minimum 3.6 erforderlich)"
        ((CHECKS_FAILED++))
    fi
fi

check_python_module "sqlite3" "SQLite3 Module"
check_python_module "configparser" "ConfigParser Module"
check_python_module "hashlib" "Hashlib Module"
check_python_module "concurrent.futures" "Concurrent Module"
check_python_module "tabulate" "Tabulate Module (optional)"
echo ""

# Installation
echo -e "${BLUE}[2] Installation Files${NC}"
check_file "/etc/rapiba/rapiba.conf" "Konfigurationsdatei"
check_dir "/usr/local/lib/rapiba" "Biblioteken-Verzeichnis"
check_file "/usr/local/bin/rapiba" "Hauptcommand"
check_file "/usr/local/bin/rapiba_monitor" "Monitor-Script"
check_file "/usr/local/bin/rapiba_trigger" "Trigger-Script"
echo ""

# Directories
echo -e "${BLUE}[3] Erforderliche Verzeichnisse${NC}"
check_dir "/backup" "Backup-Zielverzeichnis"
check_dir "/var/lib/rapiba" "Datenbank-Verzeichnis"
check_dir "/var/log/rapiba" "Log-Verzeichnis"
echo ""

# systemd
echo -e "${BLUE}[4] systemd Integration${NC}"
check_file "/etc/systemd/system/rapiba.service" "Service-Datei"
check_file "/etc/systemd/system/rapiba-backup.service" "Scheduled Backup Service"
check_file "/etc/systemd/system/rapiba-backup.timer" "Backup-Timer"
check_file "/etc/udev/rules.d/99-rapiba.rules" "udev Rules"
echo ""

# Service Status
echo -e "${BLUE}[5] Service Status${NC}"
check_service_status "rapiba"
echo ""

# Permissions
echo -e "${BLUE}[6] Berechtigungen${NC}"
if [ -f "/backup" ] || [ -d "/backup" ]; then
    check_permissions "/backup" "755" "Backup-Verzeichnis"
fi
if [ -d "/var/lib/rapiba" ]; then
    check_permissions "/var/lib/rapiba" "755" "Datenbank-Verzeichnis"
fi
echo ""

# Config Validation
echo -e "${BLUE}[7] Konfiguration${NC}"
if [ -f "/etc/rapiba/rapiba.conf" ]; then
    if python3 -c "
import sys
sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import Config
config = Config('/etc/rapiba/rapiba.conf')
target = config.get('BACKUP_TARGET')
sources = config.get('BACKUP_SOURCES')
method = config.get('DUPLICATE_CHECK_METHOD')
if not target:
    print('ERROR: BACKUP_TARGET nicht gesetzt')
    sys.exit(1)
print('OK')
" 2>/dev/null | grep -q "OK"; then
        echo -e "${GREEN}✓${NC} Konfiguration gültig"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} Konfiguration ungültig"
        ((CHECKS_FAILED++))
    fi
fi
echo ""

# Database
echo -e "${BLUE}[8] Datenbank${NC}"
if [ -f "/var/lib/rapiba/duplicate_db.sqlite3" ]; then
    if sqlite3 /var/lib/rapiba/duplicate_db.sqlite3 ".tables" 2>/dev/null | grep -q "file_hashes"; then
        echo -e "${GREEN}✓${NC} Duplikat-Datenbank funktioniert"
        ((CHECKS_PASSED++))
    else
        echo -e "${YELLOW}⚠${NC} Duplikat-Datenbank leer oder korrupt"
        ((CHECKS_WARNING++))
    fi
else
    echo -e "${YELLOW}⚠${NC} Duplikat-Datenbank existiert nicht (wird beim ersten Backup erstellt)"
    ((CHECKS_WARNING++))
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "Ergebnisse:"
echo -e "  ${GREEN}✓ Bestanden: $CHECKS_PASSED${NC}"
echo -e "  ${YELLOW}⚠ Warnungen: $CHECKS_WARNING${NC}"
echo -e "  ${RED}✗ Fehler: $CHECKS_FAILED${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}Installation erfolgreich!${NC}"
    echo ""
    echo "Nächste Schritte:"
    echo "  1. Teste mit: rapiba --list-devices"
    echo "  2. Starten: systemctl start rapiba"
    echo "  3. Logs: journalctl -u rapiba -f"
    exit 0
else
    echo -e "${RED}Installation hat Fehler!${NC}"
    echo ""
    echo "Prüfe die Fehler oben und behebe sie."
    exit 1
fi
