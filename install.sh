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
echo "[0/9] Prüfe Python3..."
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

echo "[1/9] Erstelle Verzeichnisse..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$VAR_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "/backup"

echo "[2/9] Kopiere Python-Module..."
cp src/backup_handler.py "$INSTALL_DIR/"
cp src/rapiba_monitor.py "$INSTALL_DIR/"
cp src/rapiba_trigger.py "$INSTALL_DIR/"
cp src/rapiba_admin.py "$INSTALL_DIR/"

echo "[3/9] Kopiere Konfigurationsdatei..."
if [ ! -f "$CONFIG_DIR/rapiba.conf" ]; then
    # Stelle sicher, dass die Config-Datei einen INI-Section-Header hat
    if ! grep -q "^\[rapiba\]" etc/rapiba.conf; then
        echo "[rapiba]" > "$CONFIG_DIR/rapiba.conf"
        cat etc/rapiba.conf >> "$CONFIG_DIR/rapiba.conf"
        echo "  Konfiguration mit INI-Header installiert: $CONFIG_DIR/rapiba.conf"
    else
        cp etc/rapiba.conf "$CONFIG_DIR/"
        echo "  Konfiguration installiert: $CONFIG_DIR/rapiba.conf"
    fi
    chmod 644 "$CONFIG_DIR/rapiba.conf"
else
    echo "  Konfiguration existiert bereits"
    # Prüfe ob existierende Config einen Header hat
    if ! grep -q "^\[rapiba\]" "$CONFIG_DIR/rapiba.conf"; then
        echo "  Warnung: Existierende Konfiguration hat keinen [rapiba]-Header!"
        echo "  Bitte manuell bearbeiten oder Backup löschen und Script neu ausführen"
    fi
    cp etc/rapiba.conf "$CONFIG_DIR/rapiba.conf.new"
    echo "  Neue Konfiguration als Referenz: $CONFIG_DIR/rapiba.conf.new"
fi

echo "[4/9] Erstelle ausführbare Scripte..."
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

echo "[5/9] Installiere systemd Services..."
cp systemd/rapiba.service "$SYSTEMD_DIR/"
cp systemd/rapiba-backup.service "$SYSTEMD_DIR/"
cp systemd/rapiba-backup.timer "$SYSTEMD_DIR/"
systemctl daemon-reload
echo "  Services installiert"
echo "  Hauptservice: rapiba.service (kontinuierliche Überwachung)"
echo "  Geplante Backups: rapiba-backup.service + rapiba-backup.timer"

echo "[6/9] Installiere udev Rules..."
cp udev/99-rapiba.rules "$UDEV_DIR/"
udevadm control --reload-rules
udevadm trigger
echo "  udev Rules installiert"

echo "[7/9] Setze Berechtigungen..."
chmod 755 "$INSTALL_DIR"
chmod 755 "$VAR_DIR"
chmod 755 "$LOG_DIR"
chmod 755 "/backup"
chown -R root:root "$INSTALL_DIR"
chown -R root:root "$CONFIG_DIR"
chown -R root:root "$VAR_DIR"
chown -R root:root "$LOG_DIR"

echo "[8/9] Prüfe Python-Abhängigkeiten..."
if ! python3 -c "import sqlite3" 2>/dev/null; then
    echo "  Warnung: sqlite3 nicht verfügbar"
fi

echo "[9/9] Validiere Installation..."
# Prüfe ob alle wichtigen Dateien installiert wurden
VALIDATION_FAILED=0

check_file() {
    local file=$1
    local description=$2
    if [ -f "$file" ]; then
        echo "  ✓ $description"
    else
        echo "  ✗ $description (FEHLER: nicht gefunden)"
        VALIDATION_FAILED=1
    fi
}

check_dir() {
    local dir=$1
    local description=$2
    if [ -d "$dir" ]; then
        echo "  ✓ $description"
    else
        echo "  ✗ $description (FEHLER: nicht gefunden)"
        VALIDATION_FAILED=1
    fi
}

check_file "$CONFIG_DIR/rapiba.conf" "Konfigurationsdatei"
check_dir "$INSTALL_DIR" "Python-Module Verzeichnis"
check_file "$INSTALL_DIR/backup_handler.py" "backup_handler.py"
check_file "$INSTALL_DIR/rapiba_monitor.py" "rapiba_monitor.py"
check_file "$INSTALL_DIR/rapiba_trigger.py" "rapiba_trigger.py"
check_file "$INSTALL_DIR/rapiba_admin.py" "rapiba_admin.py"
check_file "$BIN_DIR/rapiba" "rapiba Befehl"
check_file "$BIN_DIR/rapiba_monitor" "rapiba_monitor Befehl"
check_file "$BIN_DIR/rapiba_trigger" "rapiba_trigger Befehl"
check_file "$SYSTEMD_DIR/rapiba.service" "systemd Service"
check_file "$SYSTEMD_DIR/rapiba-backup.service" "systemd Backup Service"
check_file "$SYSTEMD_DIR/rapiba-backup.timer" "systemd Backup Timer"
check_file "$UDEV_DIR/99-rapiba.rules" "udev Rules"
check_dir "/backup" "Backup-Verzeichnis"
check_dir "$VAR_DIR" "Datenbank-Verzeichnis"
check_dir "$LOG_DIR" "Log-Verzeichnis"

if [ $VALIDATION_FAILED -eq 1 ]; then
    echo ""
    echo "FEHLER: Einige Dateien wurden nicht installiert!"
    exit 1
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
