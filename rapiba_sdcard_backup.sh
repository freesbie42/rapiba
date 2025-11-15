#!/bin/bash

# RapiBa SD-Karten Backup Script - Neu und einfach
# Erstellt: $(date)

# Konfiguration
BACKUP_BASE="/rapiba_backup"
MOUNT_POINT="/mnt/sdcard"
ID_FILE=".rapiba_id"
LOG_FILE="$HOME/rapiba_backup.log"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging-Funktion
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
    echo -e "$1"
}

# SD-Karte mounten - einfach und funktional
mount_sdcard() {
    local device="$1"
    local readonly="${2:-false}"  # Standard: read-write
    
    sudo mkdir -p "$MOUNT_POINT"
    
    if mountpoint -q "$MOUNT_POINT"; then
        echo "SD-Karte bereits gemountet."
        return 0
    fi
    
    if [ "$readonly" = "true" ]; then
        echo "Mounte $device (read-only)..."
    else
        echo "Mounte $device (read-write)..."
    fi
    
    # Versuche verschiedene Dateisysteme
    local fstypes=("exfat" "vfat" "ntfs" "auto")
    
    for fstype in "${fstypes[@]}"; do
        echo "Versuche Mount mit Dateisystem: $fstype"
        
        local mount_opts=""
        if [ "$readonly" = "true" ]; then
            mount_opts="-o ro"
        fi
        
        if sudo mount -t "$fstype" $mount_opts "$device" "$MOUNT_POINT" 2>/dev/null; then
            if mountpoint -q "$MOUNT_POINT"; then
                if [ "$readonly" = "true" ]; then
                    echo "✓ SD-Karte gemountet ($fstype, read-only)."
                else
                    echo "✓ SD-Karte gemountet ($fstype, read-write)."
                fi
                return 0
            fi
        fi
    done
    
    echo ""
    echo -e "${RED}✗ Mount fehlgeschlagen${NC}"
    echo -e "${YELLOW}Mögliche Ursachen:${NC}"
    echo "- SD-Karte ist beschädigt oder defekt"
    echo "- Unbekanntes/beschädigtes Dateisystem"
    echo "- SD-Karte ist schreibgeschützt"
    echo "- Hardware-Problem mit SD-Karten-Reader"
    echo ""
    echo -e "${BLUE}Lösungsvorschläge:${NC}"
    echo "- Andere SD-Karte verwenden"
    echo "- SD-Karte formatieren (exfat empfohlen)"
    echo "- SD-Karten-Reader prüfen"
    echo "- dmesg | tail für Details prüfen"
    
    return 1
}

# Prüft ob RapiBa ID vorhanden ist und mountet entsprechend
mount_sdcard_smart() {
    local device="$1"
    
    echo "Prüfe SD-Karte auf vorhandene RapiBa ID..."
    
    # Versuche erst read-only mount um ID zu prüfen
    if mount_sdcard "$device" "true"; then
        local id_path="$MOUNT_POINT/$ID_FILE"
        
        if [ -f "$id_path" ]; then
            echo -e "${GREEN}✓ RapiBa ID gefunden - Karte bleibt read-only gemountet${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Keine RapiBa ID gefunden - Remount als read-write für ID-Erstellung${NC}"
            unmount_sdcard
            # Mount read-write für ID-Erstellung
            mount_sdcard "$device" "false"
            return $?
        fi
    else
        return 1
    fi
}

# SD-Karte unmounten
unmount_sdcard() {
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Unmounte SD-Karte..."
        sync
        sudo umount "$MOUNT_POINT" 2>/dev/null
        echo "✓ SD-Karte unmountet."
    fi
}

# RapiBa ID lesen oder erstellen
read_rapiba_id() {
    local id_path="$MOUNT_POINT/$ID_FILE"
    
    if [ ! -f "$id_path" ]; then
        echo ""
        echo -e "${YELLOW}⚠ Keine RapiBa ID gefunden!${NC}"
        echo -e "${BLUE}Diese SD-Karte hat noch keine .rapiba_id Datei.${NC}"
        echo ""
        
        while true; do
            read -p "Soll eine neue RapiBa ID erstellt werden? [j/n]: " response
            case $response in
                [Jj]*|[Yy]*)
                    echo ""
                    echo "Erstelle neue RapiBa ID..."
                    
                    # Generiere neue unique ID
                    local new_id=$(generate_unique_id)
                    
                    # Schreibe ID auf SD-Karte
                    echo "$new_id" | sudo tee "$id_path" > /dev/null
                    sync
                    
                    echo -e "${GREEN}✓ Neue RapiBa ID erstellt: $new_id${NC}"
                    echo "$new_id"
                    return 0
                    ;;
                [Nn]*)
                    echo -e "${YELLOW}Keine ID erstellt. Backup abgebrochen.${NC}"
                    return 1
                    ;;
                *)
                    echo "Bitte 'j' für Ja oder 'n' für Nein eingeben."
                    ;;
            esac
        done
    fi
    
    local rapiba_id=$(cat "$id_path" | tr -d '\n\r')
    
    if [ -z "$rapiba_id" ]; then
        echo -e "${RED}✗ RapiBa ID-Datei ist leer!${NC}"
        echo "Lösche defekte ID-Datei und versuche erneut..."
        sudo rm -f "$id_path"
        return 1
    fi
    
    echo "$rapiba_id"
    return 0
}

# Funktion: Zufällige 2-stellige Hex-ID generieren
generate_id() {
    printf "%02X" $((RANDOM % 256))
}

# Funktion: Prüfen, ob ID bereits vergeben ist
is_id_unique() {
    local id="$1"
    local db_file="$HOME/rapiba_ids.db"
    
    # Erstelle DB-Datei falls nicht vorhanden
    touch "$db_file"
    
    # Prüfe ob ID bereits in DB
    if grep -q "^$id$" "$db_file" 2>/dev/null; then
        return 1  # ID bereits vergeben
    else
        return 0  # ID ist unique
    fi
}

# Funktion: Neue, unique ID generieren
generate_unique_id() {
    local id
    local attempts=0
    local max_attempts=256
    
    while [ $attempts -lt $max_attempts ]; do
        id=$(generate_id)
        if is_id_unique "$id"; then
            # Füge ID zur Datenbank hinzu
            echo "$id" >> "$HOME/rapiba_ids.db"
            echo "$id"
            return 0
        fi
        ((attempts++))
    done
    
    # Fallback wenn alle IDs vergeben sind (sehr unwahrscheinlich)
    echo "FF"
    return 0
}

# Speicherplatz prüfen und anzeigen
check_space() {
    local rapiba_id="$1"
    
    echo ""
    echo -e "${CYAN}=== Backup-Analyse ===${NC}"
    
    # SD-Karte Größe
    local source_size=$(du -sh "$MOUNT_POINT" | cut -f1)
    local source_bytes=$(du -sb "$MOUNT_POINT" | cut -f1)
    local source_mb=$((source_bytes / 1024 / 1024))
    
    echo -e "${BLUE}SD-Karte (ID: $rapiba_id):${NC} $source_size"
    
    # Backup-HDD Speicher
    local backup_info=$(df -h "$BACKUP_BASE" | tail -1)
    local backup_avail=$(echo "$backup_info" | awk '{print $4}')
    local backup_used=$(echo "$backup_info" | awk '{print $3}')
    
    echo -e "${BLUE}Backup-HDD:${NC} $backup_used belegt, $backup_avail verfügbar"
    
    # Speicherplatz-Check
    local backup_avail_bytes=$(df -B1 "$BACKUP_BASE" | tail -1 | awk '{print $4}')
    local backup_avail_mb=$((backup_avail_bytes / 1024 / 1024))
    local needed_mb=$((source_mb + 100))  # 100MB Puffer
    
    echo ""
    if [ $backup_avail_mb -gt $needed_mb ]; then
        echo -e "${GREEN}✓ Backup passt auf die HDD${NC} (braucht ~${source_mb}MB, ${backup_avail_mb}MB verfügbar)"
        echo ""
        
        while true; do
            read -p "Backup von RapiBa ID '$rapiba_id' starten? [Enter=Ja / n=Nein]: " response
            case $response in
                ""|[Jj]*|[Yy]*)
                    return 0
                    ;;
                [Nn]*)
                    echo "Backup abgebrochen."
                    return 1
                    ;;
                *)
                    echo "Bitte Enter drücken oder 'n' eingeben."
                    ;;
            esac
        done
    else
        local missing=$((needed_mb - backup_avail_mb))
        echo -e "${RED}✗ Backup passt NICHT auf die HDD${NC} (fehlen ${missing}MB)"
        echo "Lösche alte Backups oder verwende größere HDD."
        return 1
    fi
}

# Prüft ob bereits ein ähnliches Backup existiert
check_duplicate_backup() {
    local rapiba_id="$1"
    local id_backup_dir="$BACKUP_BASE/$rapiba_id"
    
    if [ ! -d "$id_backup_dir" ]; then
        return 0  # Keine Backups vorhanden
    fi
    
    # Finde das neueste Backup
    local latest_backup=$(ls -1t "$id_backup_dir" 2>/dev/null | head -n 1)
    if [ -z "$latest_backup" ]; then
        return 0  # Keine Backups gefunden
    fi
    
    local latest_backup_path="$id_backup_dir/$latest_backup"
    
    # Prüfe Zeitstempel (weniger als 10 Minuten alt?)
    local backup_time=$(echo "$latest_backup" | sed 's/\.//g' | cut -c1-12)  # YYYYMMDDHHMM
    local current_time=$(date '+%Y%m%d%H%M')
    local time_diff=$((current_time - backup_time))
    
    if [ $time_diff -lt 10 ]; then
        echo -e "${YELLOW}⚠ Warnung: Letztes Backup ist nur $time_diff Minuten alt!${NC}"
        echo "Letztes Backup: $latest_backup"
        echo ""
        while true; do
            read -p "Trotzdem neues Backup erstellen? [j/n]: " response
            case $response in
                [Jj]*|[Yy]*)
                    return 0  # Fortfahren
                    ;;
                [Nn]*)
                    echo -e "${BLUE}Backup abgebrochen.${NC}"
                    return 1  # Abbrechen
                    ;;
                *)
                    echo "Bitte 'j' für Ja oder 'n' für Nein eingeben."
                    ;;
            esac
        done
    fi
    
    # Prüfe Inhalt mit Checksummen (nur wenn Backup älter als 10 Minuten)
    echo "Prüfe auf Duplikate durch Inhalts-Vergleich..."
    
    # Erstelle temporäre Checksumme vom aktuellen SD-Inhalt
    local temp_checksum="/tmp/current_sd_checksum.txt"
    (cd "$MOUNT_POINT" && find . -type f -exec md5sum {} \; | sort) > "$temp_checksum"
    
    # Vergleiche mit letztem Backup
    local last_checksum="$latest_backup_path/content_checksum.txt"
    if [ -f "$last_checksum" ]; then
        if cmp -s "$temp_checksum" "$last_checksum"; then
            echo -e "${YELLOW}⚠ Identischer Inhalt erkannt!${NC}"
            echo "Die SD-Karte hat den exakt gleichen Inhalt wie das letzte Backup."
            echo "Letztes Backup: $latest_backup"
            echo ""
            while true; do
                read -p "Trotzdem Duplikat-Backup erstellen? [j/n]: " response
                case $response in
                    [Jj]*|[Yy]*)
                        rm -f "$temp_checksum"
                        return 0  # Fortfahren
                        ;;
                    [Nn]*)
                        echo -e "${BLUE}Backup übersprungen - keine Änderungen erkannt.${NC}"
                        rm -f "$temp_checksum"
                        return 1  # Abbrechen
                        ;;
                    *)
                        echo "Bitte 'j' für Ja oder 'n' für Nein eingeben."
                        ;;
                esac
            done
        fi
    fi
    
    rm -f "$temp_checksum"
    return 0  # Fortfahren
}

# Backup durchführen
do_backup() {
    local rapiba_id="$1"
    local timestamp=$(date '+%Y.%m.%d.%H.%M')
    local backup_dir="$BACKUP_BASE/$rapiba_id/$timestamp"
    
    echo ""
    echo -e "${CYAN}=== Backup wird erstellt ===${NC}"
    echo "Backup-Pfad: $backup_dir"
    
    # Erstelle Backup-Verzeichnis
    sudo mkdir -p "$backup_dir"
    
    # Info-Datei erstellen
    cat > "/tmp/backup_info.txt" << EOF
RapiBa SD-Karten Backup
======================
RapiBa ID: $rapiba_id
Datum: $(date)
Quelle: $MOUNT_POINT
Ziel: $backup_dir
Host: $(hostname)

SD-Karten Inhalt:
$(ls -la "$MOUNT_POINT")

Backup gestartet: $(date)
EOF
    sudo mv "/tmp/backup_info.txt" "$backup_dir/backup_info.txt"
    
    # Backup mit rsync
    echo "Kopiere SD-Karten-Inhalt..."
    if sudo rsync -av --progress "$MOUNT_POINT/" "$backup_dir/sdcard_content/"; then
        echo ""
        echo -e "${GREEN}✓ Backup erfolgreich!${NC}"
        
        # Statistiken
        local backup_size=$(du -sh "$backup_dir" | cut -f1)
        local file_count=$(find "$backup_dir/sdcard_content" -type f | wc -l)
        
        echo "Backup-Größe: $backup_size"
        echo "Anzahl Dateien: $file_count"
        
        # Erstelle Checksumme für zukünftige Duplikat-Erkennung
        echo "Erstelle Inhaltsprüfsumme..."
        (cd "$MOUNT_POINT" && find . -type f -exec md5sum {} \; | sort) | sudo tee "$backup_dir/content_checksum.txt" > /dev/null
        
        # Info-Datei ergänzen
        echo "" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        echo "Backup abgeschlossen: $(date)" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        echo "Status: ERFOLGREICH" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        echo "Backup-Größe: $backup_size" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        echo "Anzahl Dateien: $file_count" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        
        return 0
    else
        echo -e "${RED}✗ Backup fehlgeschlagen!${NC}"
        echo "Status: FEHLGESCHLAGEN" | sudo tee -a "$backup_dir/backup_info.txt" > /dev/null
        return 1
    fi
}

# Hauptprogramm
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    RapiBa SD-Karten Backup                        ║"
    echo "║                          - Neue Version -                         ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Prüfe Backup-HDD
    if [ ! -d "$BACKUP_BASE" ] || ! mountpoint -q "$BACKUP_BASE"; then
        echo -e "${RED}Fehler: Backup-HDD nicht verfügbar unter $BACKUP_BASE${NC}"
        echo "Führe zuerst './setup_backup_hdd.sh' aus."
        exit 1
    fi
    
    echo -e "${GREEN}✓ Backup-HDD verfügbar${NC}"
    echo ""
    
    while true; do
        echo -e "${YELLOW}Stecke eine SD-Karte mit RapiBa ID ein und drücke Enter.${NC}"
        echo -e "${YELLOW}(Strg+C zum Beenden)${NC}"
        read -r
        clear
        
        echo "Suche SD-Karten..."
        
        # Zeige verfügbare Geräte für Diagnose
        echo ""
        echo -e "${BLUE}Verfügbare Speichergeräte:${NC}"
        lsblk -f | grep -E "sd[a-z]|mmcblk" | head -10
        echo ""
        
        # Finde SD-Karten (Partitionen und ganze Geräte)
        local devices=()
        
        # Suche erst nach Partitionen
        local partitions=($(lsblk -r -o NAME,TYPE | grep 'part' | awk '{print $1}' | grep -E '^sd[a-z][0-9]$'))
        
        # Suche auch nach ganzen Geräten ohne Partitionen
        local whole_devices=($(lsblk -r -o NAME,TYPE | grep 'disk' | awk '{print $1}' | grep -E '^sd[a-z]$'))
        
        # Kombiniere beide Listen
        devices=("${partitions[@]}" "${whole_devices[@]}")
        
        # Filtere System-Partitionen und gemountete Geräte aus
        local filtered_devices=()
        for device in "${devices[@]}"; do
            # Überspringe wenn bereits gemountet unter System-Pfaden
            local mount_point=$(lsblk -r -o NAME,MOUNTPOINT "/dev/$device" 2>/dev/null | tail -1 | awk '{print $2}')
            if [[ "$mount_point" == "/" || "$mount_point" == "/boot"* || "$mount_point" == "/rapiba_backup" ]]; then
                echo "Überspringe System-Partition: /dev/$device (gemountet unter $mount_point)"
            else
                filtered_devices+=("$device")
            fi
        done
        
        if [ ${#filtered_devices[@]} -eq 0 ]; then
            echo -e "${RED}Keine verfügbare SD-Karte erkannt.${NC}"
            echo ""
            echo -e "${YELLOW}Mögliche Ursachen:${NC}"
            echo "- Keine SD-Karte eingesteckt"
            echo "- SD-Karte nicht erkannt (Hardware-Problem)"
            echo "- SD-Karte bereits system-seitig gemountet"
            echo ""
            echo "Bitte SD-Karte einstecken und erneut versuchen."
            echo ""
            continue
        fi
        
        # Verwende erste verfügbare Partition/Gerät
        local device="/dev/${filtered_devices[0]}"
        echo -e "${GREEN}✓ SD-Karte erkannt: $device${NC}"
        
        # Zeige Geräte-Info
        local device_info=$(lsblk -f "$device" 2>/dev/null | tail -1)
        if [ -n "$device_info" ]; then
            echo "Info: $device_info"
        fi
        
        # Mounte SD-Karte intelligent (read-only wenn ID vorhanden)
        if ! mount_sdcard_smart "$device"; then
            echo -e "${RED}Mount fehlgeschlagen. Versuche es mit anderer Karte.${NC}"
            echo ""
            continue
        fi
        
        # Lese RapiBa ID oder erstelle neue
        local rapiba_id
        if ! rapiba_id=$(read_rapiba_id); then
            echo ""
            echo "Ohne RapiBa ID kann kein Backup erstellt werden."
            unmount_sdcard
            echo ""
            continue
        fi
        
        echo -e "${GREEN}✓ RapiBa ID: $rapiba_id${NC}"
        
        # Prüfe auf Duplikate
        if ! check_duplicate_backup "$rapiba_id"; then
            unmount_sdcard
            echo ""
            continue
        fi
        
        # Speicherplatz prüfen und Benutzer fragen
        if check_space "$rapiba_id"; then
            # Backup durchführen
            if do_backup "$rapiba_id"; then
                echo ""
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║                  BACKUP ERFOLGREICH!                      ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
            else
                echo -e "${RED}Backup fehlgeschlagen.${NC}"
            fi
        fi
        
        # Unmount
        unmount_sdcard
        
        echo ""
        echo -e "${CYAN}Bereit für nächste SD-Karte...${NC}"
        echo ""
    done
}

# Fehlerbehandlung
trap 'echo ""; echo "Script beendet."; unmount_sdcard; exit 0' INT

# Log-Datei erstellen
touch "$LOG_FILE"

# Start
main "$@"