# src/rapiba_usb_mount.sh
#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/rapiba/usb_mount.log"
MOUNT_BASE="/media/rapiba"
DEVICE_STABILIZE_SECONDS=2
RAPIBA_USER="rapiba"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo "[$(timestamp)] $1" >> "$LOG_FILE"
}

get_ids() {
    local uid gid
    uid=$(id -u "$RAPIBA_USER" 2>/dev/null || echo 0)
    gid=$(id -g "$RAPIBA_USER" 2>/dev/null || echo 0)
    echo "$uid" "$gid"
}

get_mountpoint() {
    local devname
    devname=$(basename "$1")
    echo "$MOUNT_BASE/${devname}"
}

get_fstype() {
    local device="$1"
    local fstype=""

    sleep "$DEVICE_STABILIZE_SECONDS"

    if command -v blkid >/dev/null 2>&1; then
        fstype=$(blkid -o value -s TYPE "$device" 2>/dev/null | tr -d '\n')
    fi

    if [ -z "$fstype" ]; then
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
        log "Warte auf Blockgerät $device ($attempt/$max_attempts)..."
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
        log "Versuche exFAT-Kernel-Modul zu laden..."
        modprobe exfat 2>>"$LOG_FILE" || log "Hinweis: exFAT-Modul konnte nicht geladen werden (evtl. nicht nötig)."
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

    local fstype
    fstype="$(get_fstype "$device")"

    read RAPiba_UID RAPiba_GID < <(get_ids)

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
            :
            ;;
        *)
            log "Hinweis: Unbekanntes Dateisystem '$fstype' für $device. Verwende Standardoptionen."
            ;;
    esac

    if mount -t "$fstype" -o "$options" "$device" "$mountpoint" 2>>"$LOG_FILE"; then
        log "Erfolg: $device ($fstype) read-only gemountet unter $mountpoint"
        # WICHTIG:
        # - Keine Dateien auf dem Kamera-Dateisystem anlegen!
        # - Kein chown/chmod innerhalb von $mountpoint!
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

    awk -v base="$MOUNT_BASE" '$2 ~ "^"base"/" {print $1, $2}' /proc/mounts | while read -r dev mp; do
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
        mount_usb "$2"
        ;;
    remove)
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