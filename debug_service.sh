#!/bin/bash
# Rapiba Service Debug - Fehlerdiagnose beim Start

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Rapiba Service Debug${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}[1] Python Überprüfung${NC}"
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    echo -e "${GREEN}✓${NC} Python 3 gefunden: $PYTHON_VERSION"
    python3 -c "
import sys
print(f'  Python Path: {sys.executable}')
print(f'  Python Version: {sys.version}')
version_info = sys.version_info
if version_info.major == 3 and version_info.minor >= 6:
    print(f'  ✓ Version OK (3.{version_info.minor} >= 3.6)')
else:
    print(f'  ✗ Version zu alt (3.{version_info.minor} < 3.6 erforderlich)')
    sys.exit(1)
"
else
    echo -e "${RED}✗${NC} Python 3 nicht gefunden!"
    echo ""
    echo "Installation:"
    echo "  sudo apt-get update"
    echo "  sudo apt-get install -y python3 python3-pip"
    exit 1
fi
echo ""

echo -e "${BLUE}[2] Module Überprüfung${NC}"
if [ -f "/usr/local/lib/rapiba/rapiba_monitor.py" ]; then
    echo -e "${GREEN}✓${NC} rapiba_monitor.py existiert"
else
    echo -e "${RED}✗${NC} rapiba_monitor.py nicht gefunden"
    exit 1
fi

if [ -f "/usr/local/lib/rapiba/backup_handler.py" ]; then
    echo -e "${GREEN}✓${NC} backup_handler.py existiert"
else
    echo -e "${RED}✗${NC} backup_handler.py nicht gefunden"
    exit 1
fi
echo ""

echo -e "${BLUE}[3] Konfiguration Überprüfung${NC}"
if [ -f "/etc/rapiba/rapiba.conf" ]; then
    echo -e "${GREEN}✓${NC} Konfiguration existiert"
    
    # Teste Config laden
    if python3 -c "
import sys
sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import Config
config = Config('/etc/rapiba/rapiba.conf')
print(f'  BACKUP_TARGET: {config.get(\"BACKUP_TARGET\")}')
print(f'  BACKUP_SOURCES: {config.get(\"BACKUP_SOURCES\")}')
" 2>&1; then
        echo -e "${GREEN}✓${NC} Konfiguration lädt erfolgreich"
    else
        echo -e "${RED}✗${NC} Fehler beim Laden der Konfiguration"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Konfiguration nicht gefunden: /etc/rapiba/rapiba.conf"
    exit 1
fi
echo ""

echo -e "${BLUE}[4] Verzeichnisse Überprüfung${NC}"
for dir in "/backup" "/var/lib/rapiba" "/var/log/rapiba"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $dir existiert"
    else
        echo -e "${YELLOW}⚠${NC} $dir existiert nicht (wird erstellt beim ersten Backup)"
    fi
done
echo ""

echo -e "${BLUE}[5] Script direkt testen${NC}"
echo "Starten von: /usr/bin/python3 /usr/local/lib/rapiba/rapiba_monitor.py"
echo ""

# Timeout nach 5 Sekunden
timeout 5 python3 /usr/local/lib/rapiba/rapiba_monitor.py 2>&1 || true

echo ""
echo -e "${BLUE}[6] Service Status${NC}"
if command -v systemctl &> /dev/null; then
    systemctl status rapiba 2>&1 | head -20
else
    echo -e "${YELLOW}⚠${NC} systemctl nicht verfügbar"
fi
echo ""

echo -e "${BLUE}[7] Service Logs${NC}"
if command -v journalctl &> /dev/null; then
    echo "Letzte 20 Log-Zeilen:"
    journalctl -u rapiba -n 20 --no-pager 2>&1 || echo "Keine Logs gefunden"
else
    echo -e "${YELLOW}⚠${NC} journalctl nicht verfügbar"
fi
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Debugging abgeschlossen${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
