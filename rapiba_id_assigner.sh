#!/bin/bash

# Pfade und Dateien
MOUNT_POINT="/mnt/sdcard"
ID_FILE=".rapiba_id"
LOG_FILE="$HOME/rapiba_ids.log"
DB_FILE="$HOME/rapiba_ids.db"

# Erstelle Verzeichnisse und Dateien
mkdir -p "$MOUNT_POINT"
touch "$LOG_FILE" "$DB_FILE"

# Funktion: Zufällige 2-stellige Hex-ID generieren
generate_id() {
    printf "%02X" $((RANDOM % 256))
}

# Funktion: Prüfen, ob ID bereits vergeben ist
is_id_unique() {
    local id="$1"
    grep -q "^$id$" "$DB_FILE"
    return $?
}

# Funktion: Neue, unique ID generieren
generate_unique_id() {
    local id
    while true; do
        id=$(generate_id)
        if ! is_id_unique "$id"; then
            break
        fi
    done
    echo "$id"
}

# Funktion: SD-Karte mounten
mount_sdcard() {
    local device="$1"
    
    # Prüfe zuerst, ob bereits gemountet
    if mountpoint -q "$MOUNT_POINT"; then
        echo "Karte bereits gemountet unter $MOUNT_POINT."
        return 0
    fi
    
    # Versuche zu mounten
    echo "Mounte $device nach $MOUNT_POINT..."
    if sudo mount "$device" "$MOUNT_POINT" 2>/dev/null; then
        if mountpoint -q "$MOUNT_POINT"; then
            echo "Karte erfolgreich gemountet unter $MOUNT_POINT."
            return 0
        fi
    fi
    
    echo "Fehler: Karte konnte nicht gemountet werden."
    echo "Details:"
    lsblk -f | grep "$(basename "$device")"
    return 1
}

# Funktion: SD-Karte auswerfen
eject_sdcard() {
    sudo umount "$MOUNT_POINT" 2>/dev/null
    echo "Karte ausgeworfen."
}

# Funktion: ID schreiben und in DB speichern
write_id() {
    local device="$1"
    local id="$2"
    if mount_sdcard "$device"; then
        echo "$id" | sudo tee "$MOUNT_POINT/$ID_FILE" >/dev/null
        sync
        echo "ID $id in $MOUNT_POINT/$ID_FILE geschrieben."
        echo "$id" >> "$DB_FILE"
        echo "$(date): $device → $id" >> "$LOG_FILE"
        eject_sdcard
    fi
}

# Hauptschleife
echo "=== RapiBa ID-Assistent (Final) ==="
echo "Stecke eine SD-Karte ein und drücke Enter. Beende mit Strg+C."
echo "Log: $LOG_FILE | DB: $DB_FILE"
echo "-----------------------------"

while true; do
    read -p "Karte eingesteckt? [Enter zum Fortfahren] " -r
    clear

    # Liste aller verfügbaren SD-Karten-Partitionen (nicht nur Devices)
    echo "Suche nach SD-Karten-Partitionen..."
    PARTITIONS=($(lsblk -r -o NAME,TYPE | grep 'part' | grep -E 'mmcblk[0-9]p[0-9]|sd[a-z][0-9]' | awk '{print $1}'))

    if [ ${#PARTITIONS[@]} -eq 0 ]; then
        echo "Keine SD-Karten-Partition erkannt. Bitte Karte einstecken."
        echo "Verfügbare Geräte:"
        lsblk -f
        continue
    fi

    # Filtere bereits gemountete System-Partitionen aus
    AVAILABLE_PARTITIONS=()
    for partition in "${PARTITIONS[@]}"; do
        # Überspringe Root- und Boot-Partitionen
        if [[ "$partition" != "mmcblk0p1" && "$partition" != "mmcblk0p2" ]]; then
            AVAILABLE_PARTITIONS+=("$partition")
        fi
    done

    if [ ${#AVAILABLE_PARTITIONS[@]} -eq 0 ]; then
        echo "Keine verfügbare SD-Karten-Partition gefunden (System-Partitionen ausgeschlossen)."
        echo "Verfügbare Partitionen: ${PARTITIONS[*]}"
        continue
    fi

    # Wähle die erste verfügbare Partition
    DEVICE="/dev/${AVAILABLE_PARTITIONS[0]}"
    echo "Erkannte SD-Karten-Partition: $DEVICE"

    if mount_sdcard "$DEVICE"; then
        if [ -f "$MOUNT_POINT/$ID_FILE" ]; then
            existing_id=$(cat "$MOUNT_POINT/$ID_FILE")
            echo "Existierende ID gefunden: $existing_id"

            # Frage, ob überschrieben werden soll
            read -p "ID überschreiben? [j/n] " -r
            if [[ $REPLY =~ ^[Jj]$ ]]; then
                # Alte ID aus DB entfernen (falls vorhanden)
                sed -i "/^$existing_id$/d" "$DB_FILE"
                # Neue unique ID generieren und schreiben
                NEW_ID=$(generate_unique_id)
                write_id "$DEVICE" "$NEW_ID"
                echo "Neue unique ID vergeben: $NEW_ID"
            else
                echo "ID bleibt bestehen: $existing_id"
                # Stelle sicher, dass die ID in der DB ist
                if ! is_id_unique "$existing_id"; then
                    echo "$existing_id" >> "$DB_FILE"
                    echo "ID zur Datenbank hinzugefügt."
                fi
                eject_sdcard
            fi
        else
            # Keine ID-Datei vorhanden: Neue ID generieren
            NEW_ID=$(generate_unique_id)
            write_id "$DEVICE" "$NEW_ID"
            echo "Neue unique ID vergeben: $NEW_ID"
        fi
    fi

    echo "-----------------------------"
    echo "Nächste Karte (oder Strg+C zum Beenden)."
    echo "Bisher vergebene IDs: $(wc -l < "$DB_FILE")"
    echo "Letzte IDs: $(tail -n 5 "$DB_FILE")"
done
