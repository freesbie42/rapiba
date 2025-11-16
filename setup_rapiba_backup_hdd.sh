#!/bin/bash
set -euo pipefail

RAPIBA_USER="rapiba"
RAPIBA_UID=2000
RAPIBA_GID=2000

MOUNT_SCRIPT="/usr/local/bin/rapiba_usb_mount.sh"
MOUNT_UNIT="/etc/systemd/system/rapiba-usb-mount@.service"
CLEANUP_SERVICE_UNIT="/etc/systemd/system/rapiba-usb-cleanup.service"
CLEANUP_TIMER_UNIT="/etc/systemd/system/rapiba-usb-cleanup.timer"
UDEV_RULE="/etc/udev/rules.d/99-rapiba-usb-readonly.rules"

LOG_DIR="/var/log/rapiba"
LOG_FILE="${LOG_DIR}/usb_mount.log"
MOUNT_BASE="/media/rapiba"

GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}=== RapiBa USB-Mount Installer (Mount + Cleanup + udev) ===${RESET}"

# Root-Check
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Bitte mit sudo oder als root ausführen:${RESET}"
  echo "  sudo bash $0"
  exit 1
fi

# Prüfen, ob Benutzer rapiba existiert
if ! id -u "$RAPIBA_USER" >/dev/null 2>&1; then
  echo -e "${RED}Benutzer '$RAPIBA_USER' existiert nicht.${RESET}"
  echo "Bitte zuerst den RapiBa-Hauptinstaller ausführen, der den Benutzer anlegt."
  exit 1
fi

RAPIBA_UID=$(id -u "$RAPIBA_USER")
RAPIBA_GID=$(id -g "$RAPIBA_USER")

echo -e "${GREEN}Verwende Benutzer $RAPIBA_USER (UID=$RAPIBA_UID, GID=$RAPIBA_GID).${RESET}"

# Logverzeichnis
echo -e "${GREEN}Richte Log-Verzeichnis ${LOG_DIR} ein...${RESET}"
mkdir -p "$LOG_DIR"
chown "$RAPIBA_USER:$RAPIBA_USER" "$LOG_DIR"
chmod 755 "$LOG_DIR"

# Mount-Basisverzeichnis
echo -e "${GREEN}Richte Mount-Basis ${MOUNT_BASE} ein...${RESET}"
mkdir -p "$MOUNT_BASE"
chown "$RAPIBA_USER:$RAPIBA_USER" "$MOUNT_BASE"
chmod 755 "$MOUNT_BASE"

# === Mount-Script installieren ===
echo -e "${GREEN}Installiere ${MOUNT_SCRIPT}...${RESET}"

cat > "$MOUNT_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/rapiba/usb_mount.log"
RAPiba_UID=2000
RAPiba_GID=2000
MOUNT_BASE="/media/rapiba"
DEVICE_STABILIZE_SECONDS=2

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo "[$(timestamp)] $1" >> "$LOG_FILE"
}

get_mountpoint() {
    local devname
    devname=$(basename "$1")
    echo "$MOUNT_BASE/${devname}"
}

# Dateisystemtyp ermitteln (ohne Schreibaktionen)
get_fstype() {
    local device="$1"
    local fstype=""

    sleep "$DEVICE_STABILIZE_SECONDS"

    if command -v blkid >/dev/null 2>&1; then
        fstype=$(blkid -o value -s TYPE "$device" 2>/dev/null | tr -d '\n')
    fi

    if [ -z "$fstype" ]; then
        # kleiner Fallback: lsblk
        fstype=$(lsblk -no FSTYPE "$device" 2>/dev/null | head -n1 | tr -d '\n')
    fi

    if [ -z "$fstype" ]; then
        fstype="vfat"
        log "Warnung: Konnte Dateisystem von $device nicht ermitteln. Fallback: $fstype"
    else
        log "Erkanntes Dateisystem für $device: $fstype"
    fi

    echo "$fstype"
}

wait_for_device_stable() {
    local device="$1"
    local max_attempts=5
    local attempt=1

    while [ "$attempt" -le "$max_attempts" ]; do
        if [ -b "$device" ]; then
            break
        fi
        log "Warte auf Blockgerät $device (${attempt}/${max_attempts})..."
        sleep "$DEVICE_STABILIZE_SECONDS"
        attempt=$((attempt+1))
    done

    if [ ! -b "$device" ]; then
        log "Fehler: Blockgerät $device ist nicht verfügbar."
        return 1
    fi
    return 0
}

load_exfat_module() {
    if ! lsmod | grep -q exfat; then
        log "Lade exFAT-Kernel-Modul..."
        if modprobe exfat 2>>"$LOG_FILE"; then
            log "exFAT-Kernel-Modul geladen."
        else
            log "Hinweis: Konnte exFAT-Modul nicht laden. exFAT wird ggf. nicht unterstützt."
        fi
    fi
}

mount_usb() {
    local device="$1"
    local mountpoint
    mountpoint="$(get_mountpoint "$device")"

    log "Versuche, $device als read-only unter $mountpoint zu mounten..."

    wait_for_device_stable "$device" || return 1

    load_exfat_module

    mkdir -p "$mountpoint"
    chown "$RAPiba_UID:$RAPiba_GID" "$mountpoint"
    chmod 755 "$mountpoint"

    local fstype
    fstype="$(get_fstype "$device")"

    local options="ro,noatime,nodev,nosuid"

    case "$fstype" in
        vfat|fat|fat32)
            options="$options,uid=$RAPiba_UID,gid=$RAPiba_GID,fmask=0137,dmask=0027,utf8"
            ;;
        exfat)
            options="$options,uid=$RAPiba_UID,gid=$RAPiba_GID,fmask=0137,dmask=0027"
            ;;
        ntfs|ntfs-3g)
            options="$options,uid=$RAPiba_UID,gid=$RAPiba_GID,umask=0022"
            ;;
        ext2|ext3|ext4|btrfs|xfs)
            # read-only, keine weiteren Optionen nötig
            :
            ;;
        *)
            log "Hinweis: Unbekanntes Dateisystem '$fstype' für $device. Verwende Standardoptionen."
            ;;
    esac

    if mount -t "$fstype" -o "$options" "$device" "$mountpoint" 2>>"$LOG_FILE"; then
        log "Erfolg: $device ($fstype) read-only gemountet unter $mountpoint"
        # WICHTIG: Keine Schreiboperationen auf das Kamera-Dateisystem!
        # Keine Dateien anlegen, kein chown/chmod im gemounteten FS.
    else
        log "Fehler: Konnte $device nicht mounten."
        log "mount-Ausgabe: $(mount -t "$fstype" -o "$options" "$device" "$mountpoint" 2>&1)"
        log "dmesg (letzte 10 Zeilen): $(dmesg | tail -n 10)"
        rmdir "$mountpoint" 2>/dev/null || true
        return 1
    fi
}

unmount_usb() {
    local device="$1"
    local mountpoint
    mountpoint="$(get_mountpoint "$device")"

    log "Versuche, $device von $mountpoint zu unmounten..."

    if ! mountpoint -q "$mountpoint"; then
        log "Hinweis: $mountpoint ist nicht gemountet."
        return 0
    fi

    # Offene Dateien schließen (hart, aber effektiv)
    if command -v lsof >/dev/null 2>&1; then
        if lsof +f -- "$mountpoint" 2>/dev/null | grep -q "$mountpoint"; then
            log "Warnung: Offene Dateien auf $mountpoint. Versuche Prozesse zu beenden..."
            lsof +f -- "$mountpoint" 2>/dev/null | awk 'NR>1 {print $2}' | xargs -r kill -9 2>/dev/null || true
            sleep 1
        fi
    fi

    if umount "$mountpoint" 2>>"$LOG_FILE"; then
        log "Erfolg: $device von $mountpoint ungemountet."
        rmdir "$mountpoint" 2>/dev/null || true
    else
        log "Fehler: Konnte $mountpoint nicht unmounten. dmesg: $(dmesg | tail -n 5)"
        return 1
    fi
}

cleanup_mounts() {
    log "Starte Cleanup-Stichprobe für RapiBa-Mounts..."

    # Durchsuche /proc/mounts nach Mounts unter /media/rapiba/*
    awk -v base="$MOUNT_BASE" '$2 ~ "^"base"/" {print $1, $2}' /proc/mounts | while read -r dev mp; do
        # dev ist z.B. /dev/sdb1
        if [ ! -b "$dev" ]; then
            log "Cleanup: Gerät $dev existiert nicht mehr. Versuche Unmount von $mp ..."
            if umount "$mp" 2>>"$LOG_FILE"; then
                log "Cleanup: Erfolgreich unmountet: $mp"
                rmdir "$mp" 2>/dev/null || true
            else
                log "Cleanup: Fehler beim Unmount von $mp. dmesg: $(dmesg | tail -n 5)"
            fi
            continue
        fi

        # Versuche, Größe aus /sys/class/block zu lesen
        local devname
        devname=$(basename "$dev")
        local size_path="/sys/class/block/${devname}/size"
        local sz=""

        if [ -r "$size_path" ]; then
            sz=$(cat "$size_path" 2>/dev/null || echo "")
        fi

        if [ -z "$sz" ] || [ "$sz" = "0" ]; then
            log "Cleanup: Gerät $dev scheint entfernt oder leer (size=$sz). Versuche Unmount von $mp ..."
            if umount "$mp" 2>>"$LOG_FILE"; then
                log "Cleanup: Erfolgreich unmountet: $mp"
                rmdir "$mp" 2>/dev/null || true
            else
                log "Cleanup: Fehler beim Unmount von $mp. dmesg: $(dmesg | tail -n 5)"
            fi
        fi
    done

    log "Cleanup-Stichprobe beendet."
}

case "$1" in
    add)
        # erwartet z.B. /dev/sdb1
        mount_usb "$2"
        ;;
    remove)
        # falls irgendwann genutzt: unmount by device
        unmount_usb "$2"
        ;;
    cleanup)
        cleanup_mounts
        ;;
    *)
        log "Fehler: Unbekannte Aktion '$1'. Erwartet: add|remove|cleanup"
        exit 1
        ;;
esac
EOF

chmod +x "$MOUNT_SCRIPT"
chown root:root "$MOUNT_SCRIPT"

# === systemd-Unit für Mount ===
echo -e "${GREEN}Installiere ${MOUNT_UNIT}...${RESET}"

cat > "$MOUNT_UNIT" << EOF
[Unit]
Description=RapiBa USB Auto-Mount (read-only) for %I
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=${MOUNT_SCRIPT} add /dev/%I
EOF

chmod 644 "$MOUNT_UNIT"

# === systemd-Unit für Cleanup ===
echo -e "${GREEN}Installiere ${CLEANUP_SERVICE_UNIT} und ${CLEANUP_TIMER_UNIT}...${RESET}"

cat > "$CLEANUP_SERVICE_UNIT" << EOF
[Unit]
Description=RapiBa USB Auto-Cleanup (Unmount von entfernten/verschwundenen Geräten)

[Service]
Type=oneshot
ExecStart=${MOUNT_SCRIPT} cleanup
EOF

cat > "$CLEANUP_TIMER_UNIT" << EOF
[Unit]
Description=RapiBa USB Auto-Cleanup Timer

[Timer]
OnBootSec=30
OnUnitActiveSec=30
Unit=rapiba-usb-cleanup.service

[Install]
WantedBy=timers.target
EOF

chmod 644 "$CLEANUP_SERVICE_UNIT" "$CLEANUP_TIMER_UNIT"

# === udev-Regel (Kamera-Port 1-1.1) schreiben ===
echo -e "${GREEN}Setze udev-Regel für Kamera-Port (1-1.1) mit Auto-Mount + Auto-Backup...${RESET}"

cat > "$UDEV_RULE" << 'EOF'
# RapiBa USB Read-Only Auto-Mount + Auto-Backup (nur Kamera-Port 1-1.1)
#
# Bei Blockpartition mit Dateisystem an USB-Port 1-1.1:
#   - rapiba-usb-mount@%k.service
#   - rapiba-backup@%k.service  (falls installiert)

ACTION=="add", SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", \
  ENV{ID_FS_USAGE}=="filesystem", ENV{ID_FS_TYPE}!="swap", \
  SUBSYSTEMS=="usb", KERNELS=="1-1.1", \
  TAG+="systemd", \
  ENV{SYSTEMD_WANTS}+="rapiba-usb-mount@%k.service rapiba-backup@%k.service"
EOF

chmod 644 "$UDEV_RULE"

# === systemd & udev neu laden ===
echo -e "${GREEN}Aktualisiere systemd und udev...${RESET}"
systemctl daemon-reload
systemctl enable --now rapiba-usb-cleanup.timer >/dev/null 2>&1 || true
udevadm control --reload-rules
systemctl restart systemd-udevd

echo
echo -e "${GREEN}=== RapiBa USB-Mount-Installation abgeschlossen. ===${RESET}"
echo "- Mount-Script : ${MOUNT_SCRIPT}"
echo "- Mount-Unit   : ${MOUNT_UNIT}"
echo "- Cleanup      : ${CLEANUP_SERVICE_UNIT} + ${CLEANUP_TIMER_UNIT}"
echo "- udev-Regel   : ${UDEV_RULE}"
echo
echo "Beim Einstecken der Kamera am Port 1-1.1 passiert jetzt:"
echo "  1) read-only Mount nach /media/rapiba/<dev>"
echo "  2) (falls installiert) Auto-Backup via rapiba-backup@<dev>.service"
echo
echo "Cleanup unmountet automatisch, wenn die Kamera entfernt wird."
EOF