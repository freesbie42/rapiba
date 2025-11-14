#!/bin/bash
# Rapiba Quick Setup - Schnelle Konfiguration für typische Szenarien

set -e

echo "=========================================="
echo "Rapiba Quick Setup"
echo "=========================================="
echo ""

if [ "$EUID" -ne 0 ]; then
   echo "Fehler: Dieses Script muss als root ausgeführt werden"
   exit 1
fi

CONFIG_FILE="/etc/rapiba/rapiba.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Fehler: Rapiba ist noch nicht installiert"
    echo "Führe zuerst 'sudo bash install.sh' aus"
    exit 1
fi

echo "Wähle ein Szenario:"
echo ""
echo "1) Standard - Datum & Nummer, SHA256"
echo "2) Schnell - Nummer, size_time (schnell)"
echo "3) Sicher - SHA256 mit Verifikation"
echo "4) Custom - Eigene Konfiguration"
echo ""
read -p "Wahl (1-4): " scenario

backup_target="/backup"
read -p "Backup-Zielverzeichnis (Standard: $backup_target): " input
[ -z "$input" ] || backup_target="$input"

sources="/media/usb,/media/sdcard"
read -p "Backup-Quellen komma-separiert (Standard: $sources): " input
[ -z "$input" ] || sources="$input"

echo ""
echo "Konfiguriere Szenario $scenario..."
echo ""

# Backup die ursprüngliche Config
cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%s)"

case $scenario in
    1)
        echo "Standard-Konfiguration (empfohlen)"
        sed -i "s|^BACKUP_TARGET=.*|BACKUP_TARGET=$backup_target|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_SOURCES=.*|BACKUP_SOURCES=$sources|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_PATH_FORMAT=.*|BACKUP_PATH_FORMAT=both|" "$CONFIG_FILE"
        sed -i "s|^DUPLICATE_CHECK_METHOD=.*|DUPLICATE_CHECK_METHOD=sha256|" "$CONFIG_FILE"
        sed -i "s|^PARALLEL_JOBS=.*|PARALLEL_JOBS=2|" "$CONFIG_FILE"
        ;;
    2)
        echo "Schnelle Konfiguration"
        sed -i "s|^BACKUP_TARGET=.*|BACKUP_TARGET=$backup_target|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_SOURCES=.*|BACKUP_SOURCES=$sources|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_PATH_FORMAT=.*|BACKUP_PATH_FORMAT=number|" "$CONFIG_FILE"
        sed -i "s|^DUPLICATE_CHECK_METHOD=.*|DUPLICATE_CHECK_METHOD=size_time|" "$CONFIG_FILE"
        sed -i "s|^PARALLEL_JOBS=.*|PARALLEL_JOBS=4|" "$CONFIG_FILE"
        ;;
    3)
        echo "Sichere Konfiguration"
        sed -i "s|^BACKUP_TARGET=.*|BACKUP_TARGET=$backup_target|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_SOURCES=.*|BACKUP_SOURCES=$sources|" "$CONFIG_FILE"
        sed -i "s|^BACKUP_PATH_FORMAT=.*|BACKUP_PATH_FORMAT=both|" "$CONFIG_FILE"
        sed -i "s|^DUPLICATE_CHECK_METHOD=.*|DUPLICATE_CHECK_METHOD=sha256|" "$CONFIG_FILE"
        sed -i "s|^VERIFY_CHECKSUMS=.*|VERIFY_CHECKSUMS=yes|" "$CONFIG_FILE"
        sed -i "s|^PARALLEL_JOBS=.*|PARALLEL_JOBS=1|" "$CONFIG_FILE"
        ;;
    4)
        echo "Öffne Editor für Custom-Konfiguration"
        nano "$CONFIG_FILE"
        ;;
esac

# Erstelle Verzeichnisse
mkdir -p "$backup_target"
mkdir -p "/var/lib/rapiba"
mkdir -p "/var/log/rapiba"

# Setze Berechtigungen
chmod 755 "$backup_target"
chown root:root "$backup_target"

echo ""
echo "=========================================="
echo "Setup abgeschlossen!"
echo "=========================================="
echo ""
echo "Aktuelle Konfiguration:"
echo "  Ziel: $backup_target"
echo "  Quellen: $sources"
echo ""

if systemctl is-active --quiet rapiba; then
    echo "Service läuft bereits, neustarten..."
    systemctl restart rapiba
else
    echo "Service starten?"
    read -p "Jetzt starten und autostart aktivieren? (ja/nein): " start
    if [ "$start" = "ja" ]; then
        systemctl start rapiba
        systemctl enable rapiba
        echo "Service gestartet und autostart aktiviert"
    fi
fi

echo ""
echo "Nächste Schritte:"
echo "  - Prüfe Logs: journalctl -u rapiba -f"
echo "  - Manuelles Backup: rapiba --backup-now"
echo "  - Statistiken: rapiba_admin --stats"
echo ""
