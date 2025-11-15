#!/bin/bash

# Backup HDD Setup Script für RapiBa
# Erstellt: $(date)

# Konfiguration
MOUNT_POINT="/rapiba_backup"
FSTAB_FILE="/etc/fstab"
LOG_FILE="$HOME/backup_hdd_setup.log"

# Farben für bessere Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging-Funktion
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Funktion: Benutzerbestätigung
confirm_action() {
    local message="$1"
    while true; do
        echo -e "${YELLOW}$message [j/n]: ${NC}"
        read -r response
        case $response in
            [Jj]|[Jj]a|[Yy]|[Yy]es) 
                return 0 
                ;;
            [Nn]|[Nn]ein|[Nn]o) 
                return 1 
                ;;
            *) 
                echo -e "${RED}Bitte mit 'j' oder 'n' antworten.${NC}"
                ;;
        esac
    done
}

# Funktion: Verfügbare externe Festplatten anzeigen
show_available_drives() {
    echo -e "${BLUE}Verfügbare Speichergeräte:${NC}"
    lsblk -f -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | grep -v loop
    echo ""
}

# Funktion: Externe HDDs erkennen
detect_external_hdds() {
    # Suche nach USB-Festplatten und großen SD-Karten (> 16GB)
    local external_drives=()
    
    # USB-Geräte
    for device in $(lsblk -d -o NAME,TRAN | grep usb | awk '{print $1}'); do
        # Prüfe Partitionen des Geräts
        for partition in $(lsblk -r -o NAME,TYPE /dev/$device | grep part | awk '{print $1}'); do
            external_drives+=("$partition")
        done
    done
    
    # Große SD-Karten (nicht System-SD-Karte)
    for partition in $(lsblk -r -o NAME,TYPE,SIZE | grep part | awk '$3 ~ /^[0-9]+G$/ && $3+0 > 16 {print $1}'); do
        if [[ "$partition" != "mmcblk0p1" && "$partition" != "mmcblk0p2" ]]; then
            external_drives+=("$partition")
        fi
    done
    
    echo "${external_drives[@]}"
}

# Funktion: Mount-Point vorbereiten
prepare_mount_point() {
    log_message "${BLUE}Bereite Mount-Point vor: $MOUNT_POINT${NC}"
    
    if [ -d "$MOUNT_POINT" ]; then
        if mountpoint -q "$MOUNT_POINT"; then
            log_message "${YELLOW}$MOUNT_POINT ist bereits gemountet. Unmounte zuerst...${NC}"
            if ! sudo umount "$MOUNT_POINT"; then
                log_message "${RED}Fehler beim Unmounten von $MOUNT_POINT${NC}"
                return 1
            fi
        fi
    else
        log_message "Erstelle Verzeichnis $MOUNT_POINT"
        if ! sudo mkdir -p "$MOUNT_POINT"; then
            log_message "${RED}Fehler beim Erstellen von $MOUNT_POINT${NC}"
            return 1
        fi
    fi
    
    return 0
}

# Funktion: Festplatte mounten und testen
mount_and_test_drive() {
    local device="$1"
    local fstype="$2"
    
    log_message "${BLUE}Mounte $device nach $MOUNT_POINT...${NC}"
    
    if ! sudo mount "$device" "$MOUNT_POINT"; then
        log_message "${RED}Fehler beim Mounten von $device${NC}"
        return 1
    fi
    
    # Test-Datei erstellen
    local test_file="$MOUNT_POINT/.rapiba_backup_test"
    if echo "RapiBa Backup HDD Test - $(date)" | sudo tee "$test_file" > /dev/null; then
        log_message "${GREEN}Schreibtest erfolgreich${NC}"
        sudo rm -f "$test_file"
    else
        log_message "${RED}Schreibtest fehlgeschlagen${NC}"
        sudo umount "$MOUNT_POINT"
        return 1
    fi
    
    log_message "${GREEN}$device erfolgreich gemountet und getestet${NC}"
    return 0
}

# Funktion: fstab-Eintrag erstellen
add_to_fstab() {
    local device="$1"
    local fstype="$2"
    
    # UUID ermitteln
    local uuid=$(sudo blkid -s UUID -o value "$device")
    if [ -z "$uuid" ]; then
        log_message "${RED}Konnte UUID für $device nicht ermitteln${NC}"
        return 1
    fi
    
    # Prüfe ob bereits ein Eintrag existiert
    if grep -q "$MOUNT_POINT" "$FSTAB_FILE"; then
        log_message "${YELLOW}Entferne bestehenden Eintrag für $MOUNT_POINT aus fstab${NC}"
        sudo sed -i "\|$MOUNT_POINT|d" "$FSTAB_FILE"
    fi
    
    # Mount-Optionen je nach Dateisystem
    local mount_opts
    case "$fstype" in
        ext4|ext3|ext2)
            mount_opts="defaults,nofail"
            ;;
        ntfs)
            mount_opts="defaults,nofail,uid=1000,gid=1000,umask=0022"
            ;;
        exfat|vfat)
            mount_opts="defaults,nofail,uid=1000,gid=1000,umask=0022"
            ;;
        *)
            mount_opts="defaults,nofail"
            ;;
    esac
    
    # Backup der fstab erstellen
    sudo cp "$FSTAB_FILE" "$FSTAB_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    log_message "Backup der fstab erstellt"
    
    # Neuen Eintrag hinzufügen
    local fstab_entry="UUID=$uuid $MOUNT_POINT $fstype $mount_opts 0 2"
    echo "$fstab_entry" | sudo tee -a "$FSTAB_FILE" > /dev/null
    
    log_message "${GREEN}fstab-Eintrag hinzugefügt:${NC}"
    log_message "$fstab_entry"
    
    # fstab-Syntax testen
    if sudo mount -a; then
        log_message "${GREEN}fstab-Syntax korrekt${NC}"
        return 0
    else
        log_message "${RED}Fehler in fstab-Syntax! Wiederherstellung...${NC}"
        sudo cp "$FSTAB_FILE.backup.$(date +%Y%m%d)_"* "$FSTAB_FILE"
        return 1
    fi
}

# Funktion: Backup-Verzeichnisse erstellen
create_backup_structure() {
    log_message "${BLUE}Erstelle Backup-Verzeichnisstruktur...${NC}"
    
    local backup_dirs=(
        "$MOUNT_POINT/rapiba_configs"
        "$MOUNT_POINT/rapiba_logs" 
        "$MOUNT_POINT/rapiba_data"
        "$MOUNT_POINT/system_configs"
        "$MOUNT_POINT/user_data"
    )
    
    for dir in "${backup_dirs[@]}"; do
        if sudo mkdir -p "$dir"; then
            log_message "✓ $dir erstellt"
        else
            log_message "${RED}✗ Fehler beim Erstellen von $dir${NC}"
            return 1
        fi
    done
    
    # README-Datei erstellen
    cat << 'EOF' | sudo tee "$MOUNT_POINT/README_RAPIBA_BACKUP.txt" > /dev/null
=== RapiBa Backup HDD ===
Erstellt am: $(date)

Verzeichnisstruktur:
- rapiba_configs/ : RapiBa Konfigurationsdateien
- rapiba_logs/    : RapiBa Log-Dateien  
- rapiba_data/    : RapiBa Daten und IDs
- system_configs/ : System-Konfigurationen
- user_data/      : Benutzer-Daten

Diese HDD ist automatisch in /etc/fstab eingetragen
und wird beim Boot automatisch unter /rapiba_backup gemountet.
EOF
    
    log_message "${GREEN}Backup-Verzeichnisstruktur erstellt${NC}"
    return 0
}

# Hauptprogramm
main() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    RapiBa Backup HDD Setup                  ║"
    echo "║                                                              ║"
    echo "║  Dieses Skript richtet eine externe Festplatte als          ║"
    echo "║  automatische Backup-HDD für das RapiBa-System ein.         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_message "=== RapiBa Backup HDD Setup gestartet ==="
    
    echo -e "${YELLOW}Bitte stecken Sie jetzt eine externe Festplatte ein.${NC}"
    echo -e "${YELLOW}Drücken Sie Enter, wenn die Festplatte angeschlossen ist...${NC}"
    read -r
    
    echo ""
    show_available_drives
    
    # Erkenne externe Festplatten
    local external_drives=($(detect_external_hdds))
    
    if [ ${#external_drives[@]} -eq 0 ]; then
        log_message "${RED}Keine externe Festplatte erkannt!${NC}"
        echo -e "${RED}Mögliche Ursachen:${NC}"
        echo "- Festplatte nicht eingesteckt"
        echo "- USB-Port defekt"
        echo "- Festplatte nicht partitioniert"
        exit 1
    fi
    
    echo -e "${GREEN}Erkannte externe Festplatte(n):${NC}"
    for i in "${!external_drives[@]}"; do
        local partition="${external_drives[$i]}"
        local info=$(lsblk -f "/dev/$partition" | tail -1)
        echo "  $((i+1)). /dev/$partition - $info"
    done
    echo ""
    
    # Festplatte auswählen
    local selected_device
    if [ ${#external_drives[@]} -eq 1 ]; then
        selected_device="/dev/${external_drives[0]}"
        echo -e "${BLUE}Verwende automatisch: $selected_device${NC}"
    else
        while true; do
            echo -e "${YELLOW}Welche Festplatte verwenden? [1-${#external_drives[@]}]: ${NC}"
            read -r choice
            if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#external_drives[@]}" ]; then
                selected_device="/dev/${external_drives[$((choice-1))]}"
                break
            else
                echo -e "${RED}Ungültige Auswahl. Bitte Zahl zwischen 1 und ${#external_drives[@]} eingeben.${NC}"
            fi
        done
    fi
    
    # Dateisystem ermitteln
    local fstype=$(lsblk -f -o FSTYPE "$selected_device" | tail -1 | xargs)
    if [ -z "$fstype" ]; then
        log_message "${RED}Konnte Dateisystem von $selected_device nicht ermitteln${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}Gewählte Festplatte: $selected_device${NC}"
    echo -e "${BLUE}Dateisystem: $fstype${NC}"
    echo -e "${BLUE}Mount-Point: $MOUNT_POINT${NC}"
    echo ""
    
    # Wichtige Warnung
    echo -e "${RED}⚠ ACHTUNG ⚠${NC}"
    echo -e "${RED}Diese Aktion wird:${NC}"
    echo -e "${RED}1. Die Festplatte unter $MOUNT_POINT mounten${NC}"
    echo -e "${RED}2. Einen permanenten Eintrag in /etc/fstab erstellen${NC}"
    echo -e "${RED}3. Backup-Verzeichnisse auf der Festplatte erstellen${NC}"
    echo ""
    
    if ! confirm_action "Möchten Sie fortfahren?"; then
        log_message "Setup abgebrochen durch Benutzer"
        echo -e "${YELLOW}Setup abgebrochen.${NC}"
        exit 0
    fi
    
    # Setup durchführen
    echo ""
    log_message "${BLUE}Starte Setup-Prozess...${NC}"
    
    # 1. Mount-Point vorbereiten
    if ! prepare_mount_point; then
        exit 1
    fi
    
    # 2. Festplatte mounten und testen
    if ! mount_and_test_drive "$selected_device" "$fstype"; then
        exit 1
    fi
    
    # 3. fstab-Eintrag hinzufügen
    if ! add_to_fstab "$selected_device" "$fstype"; then
        echo -e "${RED}Fehler beim fstab-Setup. Unmounte Festplatte...${NC}"
        sudo umount "$MOUNT_POINT"
        exit 1
    fi
    
    # 4. Backup-Struktur erstellen
    if ! create_backup_structure; then
        echo -e "${RED}Fehler beim Erstellen der Backup-Struktur${NC}"
        exit 1
    fi
    
    # Erfolgsmeldung
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    SETUP ERFOLGREICH!                       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}✓ Backup-HDD erfolgreich eingerichtet${NC}"
    echo -e "${GREEN}✓ Festplatte: $selected_device${NC}"
    echo -e "${GREEN}✓ Mount-Point: $MOUNT_POINT${NC}"
    echo -e "${GREEN}✓ fstab-Eintrag erstellt${NC}"
    echo -e "${GREEN}✓ Backup-Verzeichnisse erstellt${NC}"
    echo ""
    echo -e "${BLUE}Die Festplatte wird beim nächsten Systemstart automatisch gemountet.${NC}"
    echo -e "${BLUE}Verfügbarer Speicher:${NC}"
    df -h "$MOUNT_POINT" | tail -1
    echo ""
    echo -e "${BLUE}Log-Datei: $LOG_FILE${NC}"
    
    log_message "=== RapiBa Backup HDD Setup erfolgreich abgeschlossen ==="
}

# Fehlerbehandlung
set -e
trap 'log_message "${RED}Fehler in Zeile $LINENO. Setup abgebrochen.${NC}"; exit 1' ERR

# Root-Rechte prüfen
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Bitte führe dieses Skript NICHT als root aus!${NC}"
    echo "Verwende: ./setup_backup_hdd.sh"
    exit 1
fi

# Hauptprogramm ausführen
main "$@"