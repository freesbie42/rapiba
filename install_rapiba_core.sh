# install_rapiba_core.sh
#!/bin/bash
set -euo pipefail

RAPIBA_USER="rapiba"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/src"

MOUNT_SCRIPT_TARGET="/usr/local/bin/rapiba_usb_mount.sh"
BACKUP_SCRIPT_TARGET="/usr/local/bin/rapiba_backup.sh"

MOUNT_UNIT_TARGET="/etc/systemd/system/rapiba-usb-mount@.service"
BACKUP_UNIT_TARGET="/etc/systemd/system/rapiba-backup@.service"
CLEANUP_SERVICE_TARGET="/etc/systemd/system/rapiba-usb-cleanup.service"
CLEANUP_TIMER_TARGET="/etc/systemd/system/rapiba-usb-cleanup.timer"

UDEV_RULE_TARGET="/etc/udev/rules.d/99-rapiba-usb-readonly.rules"

LOG_DIR="/var/log/rapiba"
MOUNT_BASE="/media/rapiba"

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

echo -e "${GREEN}=== RapiBa Core Installer (aus src/) ===${RESET}"

# Root-Check
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}Bitte mit sudo oder als root ausführen:${RESET}"
  echo "  sudo bash $0"
  exit 1
fi

# Benutzer prüfen
if ! id -u "$RAPIBA_USER" >/dev/null 2>&1; then
  echo -e "${RED}Benutzer '$RAPIBA_USER' existiert nicht.${RESET}"
  exit 1
fi

# src-Verzeichnis prüfen
if [[ ! -d "$SRC_DIR" ]]; then
  echo -e "${RED}src-Verzeichnis nicht gefunden: ${SRC_DIR}${RESET}"
  exit 1
fi

# Prüfen, ob alle Dateien existieren
REQUIRED_FILES=(
  "rapiba_usb_mount.sh"
  "rapiba_backup.sh"
  "rapiba-usb-mount@.service"
  "rapiba-backup@.service"
  "rapiba-usb-cleanup.service"
  "rapiba-usb-cleanup.timer"
  "99-rapiba-usb-readonly.rules"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "${SRC_DIR}/${f}" ]]; then
    echo -e "${RED}Fehlende Datei in src/: ${f}${RESET}"
    exit 1
  fi
done

echo -e "${GREEN}Kopiere Scripts nach /usr/local/bin ...${RESET}"
install -m 0755 "${SRC_DIR}/rapiba_usb_mount.sh" "$MOUNT_SCRIPT_TARGET"
install -m 0755 "${SRC_DIR}/rapiba_backup.sh" "$BACKUP_SCRIPT_TARGET"

echo -e "${GREEN}Kopiere systemd-Units nach /etc/systemd/system ...${RESET}"
install -m 0644 "${SRC_DIR}/rapiba-usb-mount@.service" "$MOUNT_UNIT_TARGET"
install -m 0644 "${SRC_DIR}/rapiba-backup@.service" "$BACKUP_UNIT_TARGET"
install -m 0644 "${SRC_DIR}/rapiba-usb-cleanup.service" "$CLEANUP_SERVICE_TARGET"
install -m 0644 "${SRC_DIR}/rapiba-usb-cleanup.timer" "$CLEANUP_TIMER_TARGET"

echo -e "${GREEN}Kopiere udev-Regel nach ${UDEV_RULE_TARGET} ...${RESET}"
install -m 0644 "${SRC_DIR}/99-rapiba-usb-readonly.rules" "$UDEV_RULE_TARGET"

echo -e "${GREEN}Richte Log-Verzeichnis ${LOG_DIR} ein...${RESET}"
mkdir -p "$LOG_DIR"
chown "$RAPIBA_USER:$RAPIBA_USER" "$LOG_DIR"
chmod 755 "$LOG_DIR"

echo -e "${GREEN}Richte Mount-Basis ${MOUNT_BASE} ein...${RESET}"
mkdir -p "$MOUNT_BASE"
chmod 755 "$MOUNT_BASE"

echo -e "${GREEN}Aktualisiere systemd und udev...${RESET}"
systemctl daemon-reload
systemctl enable --now rapiba-usb-cleanup.timer >/dev/null 2>&1 || true
udevadm control --reload-rules
systemctl restart systemd-udevd

echo
echo -e "${GREEN}=== Installation abgeschlossen. ===${RESET}"
echo "Beim Einstecken der Kamera am Port 1-1.1:"
echo "  1) read-only Mount nach ${MOUNT_BASE}/<dev>"
echo "  2) Auto-Backup nach /rapiba_backup/YYYY-MM-DD_HH-MM-SS/<dev>/"
echo
echo "Logs:"
echo "  - Mount  : ${LOG_DIR}/usb_mount.log"
echo "  - Backup : ${LOG_DIR}/backup.log"