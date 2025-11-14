#!/bin/bash
# Rapiba Installation Script für Raspberry Pi
# Installiert alle notwendigen Komponenten

set -e

echo "=========================================="
echo "Rapiba - Installation"
echo "=========================================="

# Prüfe ob root
if [ "$EUID" -ne 0 ]; then
   echo "Fehler: Dieses Script muss als root ausgeführt werden"
   exit 1
fi

# Prüfe Python3 Verfügbarkeit und Minimum Version
echo "[0/8] Prüfe Python3..."
if ! command -v python3 &> /dev/null; then
   echo "Fehler: Python3 nicht installiert"
   echo "Installation auf Raspberry Pi:"
   echo "  sudo apt-get update"
   echo "  sudo apt-get install -y python3 python3-pip"
   exit 1
fi

# Prüfe Minimum Python Version (3.6+)
PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
REQUIRED_VERSION="3.6"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
   echo "Fehler: Python $PYTHON_VERSION gefunden, aber $REQUIRED_VERSION oder höher erforderlich"
   exit 1
fi

echo "✓ Python $PYTHON_VERSION gefunden"

INSTALL_DIR="/usr/local/lib/rapiba"
BIN_DIR="/usr/local/bin"
CONFIG_DIR="/etc/rapiba"
VAR_DIR="/var/lib/rapiba"
LOG_DIR="/var/log/rapiba"
SYSTEMD_DIR="/etc/systemd/system"
UDEV_DIR="/etc/udev/rules.d"

echo "[1/8] Erstelle Verzeichnisse..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$VAR_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/backup"

echo "[2/8] Kopiere Python-Module..."
cp src/backup_handler.py "$INSTALL_DIR/"
cp src/rapiba_monitor.py "$INSTALL_DIR/"
cp src/rapiba_trigger.py "$INSTALL_DIR/"

echo "[3/8] Kopiere Konfigurationsdatei..."
if [ ! -f "$CONFIG_DIR/rapiba.conf" ]; then
    cp etc/rapiba.conf "$CONFIG_DIR/"
    chmod 644 "$CONFIG_DIR/rapiba.conf"
    echo "  Konfiguration installiert: $CONFIG_DIR/rapiba.conf"
else
    echo "  Konfiguration existiert bereits"
    cp etc/rapiba.conf "$CONFIG_DIR/rapiba.conf.new"
    echo "  Neue Konfiguration als Referenz: $CONFIG_DIR/rapiba.conf.new"
fi

echo "[4/8] Erstelle ausführbare Scripte..."
cat > "$BIN_DIR/rapiba_monitor" << 'EOF'
#!/bin/bash
exec /usr/bin/python3 /usr/local/lib/rapiba/rapiba_monitor.py "$@"
EOF

cat > "$BIN_DIR/rapiba_trigger" << 'EOF'
#!/bin/bash
exec /usr/bin/python3 /usr/local/lib/rapiba/rapiba_trigger.py "$@"
EOF

cat > "$BIN_DIR/rapiba" << 'EOF'
#!/bin/bash
exec /usr/bin/python3 /usr/local/lib/rapiba/backup_handler.py --config /etc/rapiba/rapiba.conf "$@"
EOF

chmod +x "$BIN_DIR/rapiba_monitor"
chmod +x "$BIN_DIR/rapiba_trigger"
chmod +x "$BIN_DIR/rapiba"

echo "[5/8] Installiere systemd Service..."
cp systemd/rapiba.service "$SYSTEMD_DIR/"
systemctl daemon-reload
echo "  Service installiert, verwende 'systemctl start rapiba' zum Starten"

echo "[6/8] Installiere udev Rules..."
cp udev/99-rapiba.rules "$UDEV_DIR/"
udevadm control --reload-rules
udevadm trigger
echo "  udev Rules installiert"

echo "[7/8] Setze Berechtigungen..."
chmod 755 "$INSTALL_DIR"
chmod 755 "$VAR_DIR"
chmod 755 "$LOG_DIR"
chmod 755 "/backup"
chown -R root:root "$INSTALL_DIR"
chown -R root:root "$CONFIG_DIR"
chown -R root:root "$VAR_DIR"
chown -R root:root "$LOG_DIR"

echo "[8/8] Prüfe Python-Abhängigkeiten..."
if ! python3 -c "import sqlite3" 2>/dev/null; then
    echo "  Warnung: sqlite3 nicht verfügbar"
fi

echo ""
echo "=========================================="
echo "Installation abgeschlossen!"
echo "=========================================="
echo ""
echo "Nächste Schritte:"
echo ""
echo "1. Bearbeite die Konfiguration:"
echo "   nano $CONFIG_DIR/rapiba.conf"
echo ""
echo "2. Starte den Service:"
echo "   systemctl start rapiba"
echo ""
echo "3. Aktiviere AutoStart:"
echo "   systemctl enable rapiba"
echo ""
echo "4. Prüfe Status:"
echo "   systemctl status rapiba"
echo "   journalctl -u rapiba -f"
echo ""
echo "5. Manuelles Backup:"
echo "   rapiba --backup-now /media/usb"
echo ""
echo "6. Liste erkannte Geräte:"
echo "   rapiba --list-devices"
echo ""
echo "7. Liste Backups:"
echo "   rapiba --list-backups"
echo ""
