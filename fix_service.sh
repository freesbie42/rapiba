#!/bin/bash
# Rapiba Service Fix - Behebt häufige Startup-Fehler

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  Rapiba Service Fix${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
   echo -e "${RED}✗${NC} Fehler: Dieses Script muss als root ausgeführt werden"
   exit 1
fi

echo -e "${BLUE}[1] Erstelle erforderliche Verzeichnisse${NC}"
mkdir -p /backup
mkdir -p /var/lib/rapiba
mkdir -p /var/log/rapiba
echo -e "${GREEN}✓${NC} Verzeichnisse erstellt"
echo ""

echo -e "${BLUE}[2] Setze Berechtigungen${NC}"
chmod 755 /backup
chmod 755 /var/lib/rapiba
chmod 755 /var/log/rapiba
chown root:root /backup
chown root:root /var/lib/rapiba
chown root:root /var/log/rapiba
echo -e "${GREEN}✓${NC} Berechtigungen gesetzt"
echo ""

echo -e "${BLUE}[3] Überprüfe Konfigurationsdatei${NC}"
if [ ! -f "/etc/rapiba/rapiba.conf" ]; then
    echo -e "${RED}✗${NC} Konfiguration nicht gefunden!"
    exit 1
fi

# Stelle sicher dass Backup-Zielverzeichnis existiert
TARGET=$(grep "^BACKUP_TARGET=" /etc/rapiba/rapiba.conf | cut -d= -f2 | xargs)
if [ -n "$TARGET" ]; then
    mkdir -p "$TARGET"
    chmod 755 "$TARGET"
    echo -e "${GREEN}✓${NC} Backup-Zielverzeichnis existiert: $TARGET"
else
    echo -e "${YELLOW}⚠${NC} BACKUP_TARGET nicht in Config gefunden"
fi
echo ""

echo -e "${BLUE}[4] Überprüfe Python-Module${NC}"
if python3 -c "
import sys
sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import Config, DeviceDetector, BackupEngine
print('  ✓ Module laden erfolgreich')
" 2>&1; then
    echo -e "${GREEN}✓${NC} Python-Module OK"
else
    echo -e "${RED}✗${NC} Fehler beim Laden der Python-Module"
    exit 1
fi
echo ""

echo -e "${BLUE}[5] Reload systemd daemon${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓${NC} systemd reloaded"
echo ""

echo -e "${BLUE}[6] Starte Service${NC}"
systemctl stop rapiba 2>/dev/null || true
sleep 2

if systemctl start rapiba; then
    echo -e "${GREEN}✓${NC} Service gestartet"
else
    echo -e "${RED}✗${NC} Fehler beim Starten des Service"
    echo ""
    echo "Debug-Ausgabe:"
    systemctl status rapiba || true
    exit 1
fi
echo ""

echo -e "${BLUE}[7] Warte 3 Sekunden für Initialisierung${NC}"
sleep 3
echo ""

echo -e "${BLUE}[8] Überprüfe Service-Status${NC}"
if systemctl is-active --quiet rapiba; then
    echo -e "${GREEN}✓${NC} Service läuft"
else
    echo -e "${RED}✗${NC} Service läuft nicht"
    echo ""
    echo "Logs:"
    journalctl -u rapiba -n 30 --no-pager
    exit 1
fi
echo ""

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Fix abgeschlossen!${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "Service läuft jetzt erfolgreich!"
echo ""
echo "Logs ansehen:"
echo "  journalctl -u rapiba -f"
echo ""
echo "Status prüfen:"
echo "  systemctl status rapiba"
echo ""
