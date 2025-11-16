# RapiBa – Raspberry Pi Kamera-Backup Assistent
Ein autonomes, mobiles Kamera-Backup-System für Raspberry Pi 5

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi%205-red.svg)
![Status](https://img.shields.io/badge/status-Beta-green.svg)

## 📸 Über das Projekt
RapiBa ist ein vollständig autonomes Kamera-Backup-System, das Fotos und Videos automatisch von einer angeschlossenen Digitalkamera oder SD-Karte auf eine NVMe-SSD sichert.

## ✨ Funktionen
- Automatische Kamera-Erkennung
- Read-only Mount
- Automatisches Backup per rsync
- Automatisches Unmount
- exFAT/FAT32/NTFS/ext4 Support
- NVMe + Akku-Unterstützung

## Installation
```
git clone https://github.com/DEINUSER/rapiba.git
cd rapiba
sudo ./install.sh
```

## Struktur
```
rapiba/
  install.sh
  src/
    rapiba_usb_mount.sh
    rapiba_usb_unmount.sh
    rapiba_backup.sh
    99-rapiba-usb.rules
    rapiba-usb-mount@.service
    rapiba-backup@.service
    rapiba-usb-cleanup.service
    rapiba-usb-cleanup.timer
```
