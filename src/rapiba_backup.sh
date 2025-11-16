# src/rapiba_backup.sh
#!/bin/bash
set -euo pipefail

SOURCE_BASE="/media/rapiba"
DEST_BASE="/rapiba_backup"
LOG_FILE="/var/log/rapiba/backup.log"
RAPIBA_USER="rapiba"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log() {
    echo "[$(timestamp)] $1" >> "$LOG_FILE"
}

echo "=== RapiBa Kamera-Backup (non-interactive) ==="

if ! mountpoint -q "$DEST_BASE"; then
    echo "Fehler: Backup-Ziel $DEST_BASE ist nicht gemountet."
    log "Fehler: Backup-Ziel $DEST_BASE ist nicht gemountet. Abbruch."
    exit 1
fi

SRC=""

if [[ $# -ge 1 ]]; then
    DEVNAME="$1"
    CANDIDATE="${SOURCE_BASE}/${DEVNAME}"
    if mountpoint -q "$CANDIDATE"; then
        SRC="$CANDIDATE"
        log "Quelle über Parameter erkannt: $SRC"
    else
        log "Fehler: Übergebener Device-Mount $CANDIDATE ist kein Mountpoint. Abbruch."
        echo "Fehler: $CANDIDATE ist kein gültiger Mountpoint."
        exit 1
    fi
else
    mapfile -t SOURCES < <(awk -v base="$SOURCE_BASE" '$2 ~ "^"base"/" {print $2}' /proc/mounts | sort -u)

    if (( ${#SOURCES[@]} == 0 )); then
        echo "Keine Kamera-Mounts unter $SOURCE_BASE gefunden."
        log "Fehler: Keine Kamera-Mounts unter $SOURCE_BASE gefunden. Abbruch."
        exit 1
    fi

    if (( ${#SOURCES[@]} > 1 )) ; then
        log "Warnung: Mehrere Kamera-Mounts gefunden (${SOURCES[*]}). Verwende den ersten."
    fi

    SRC="${SOURCES[0]}"
    log "Quelle automatisch gewählt: $SRC"
fi

SRC_NAME="$(basename "$SRC")"

# Langes Datumformat mit Uhrzeit
TODAY="$(date +"%Y-%m-%d_%H-%M-%S")"
DEST_DIR="$DEST_BASE/$TODAY/$SRC_NAME"

echo "Quelle: $SRC"
echo "Ziel:   $DEST_DIR"

mkdir -p "$DEST_DIR"

CURRENT_USER="$(id -un || echo unknown)"
log "Backup gestartet. Quelle: $SRC, Ziel: $DEST_DIR, User: $CURRENT_USER"

RSYNC_OPTS=(-a -v --ignore-existing)

# Optional: nur Medien-Dateien:
# RSYNC_OPTS+=(--include='*/' --include='*.JPG' --include='*.JPEG' --include='*.ARW' --include='*.MP4' --include='*.MOV' --exclude='*')

TMP_LOG="/tmp/rapiba_backup_rsync.log"

echo "Starte rsync..."
if rsync "${RSYNC_OPTS[@]}" "$SRC"/ "$DEST_DIR"/ | tee "$TMP_LOG"; then
    log "rsync erfolgreich beendet. Quelle: $SRC, Ziel: $DEST_DIR"
    log "rsync-Ausgabe:"
    sed 's/^/  /' "$TMP_LOG" >> "$LOG_FILE"
    rm -f "$TMP_LOG"
    echo "Backup erfolgreich abgeschlossen."
    echo "Ziel: $DEST_DIR"
else
    RC=$?
    log "Fehler: rsync beendet mit Status $RC. Quelle: $SRC, Ziel: $DEST_DIR"
    if [[ -f "$TMP_LOG" ]]; then
        log "rsync-Ausgabe (Fehlerfall):"
        sed 's/^/  /' "$TMP_LOG" >> "$LOG_FILE"
        rm -f "$TMP_LOG"
    fi
    echo "Fehler: rsync ist mit Status $RC fehlgeschlagen."
    exit "$RC"
fi