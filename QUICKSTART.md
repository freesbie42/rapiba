# Rapiba Installation & Setup - Quick Reference

## 📦 Was wurde erstellt?

Ein vollständiges automatisches Backup-System für Raspberry Pi mit folgenden Komponenten:

### Python-Module (src/)
- **backup_handler.py** (600+ Zeilen)
  - Config-Verwaltung
  - Duplikat-Datenbank (SQLite3)
  - Hash-Berechnung (MD5/SHA256)
  - Backup-Engine mit parallelem Kopieren
  - USB/SD-Card-Erkennung

- **rapiba_monitor.py** - Kontinuierliche Geräte-Überwachung
- **rapiba_trigger.py** - udev-Integrations-Trigger
- **rapiba_admin.py** - Admin-Verwaltungstool

### Konfiguration (etc/)
- **rapiba.conf** - 40+ konfigurierbare Optionen

### systemd Integration (systemd/)
- rapiba.service - Hauptservice
- rapiba-backup.service - Geplante Backups
- rapiba-backup.timer - Timer für regelmäßige Backups

### udev Integration (udev/)
- 99-rapiba.rules - Automatische Geräte-Erkennung

### Installationsskripte
- **install.sh** - Hauptinstaller (8 Schritte)
- **quicksetup.sh** - Schnelle Konfiguration für 4 Szenarien
- **verify_installation.sh** - Installationsverifikation
- **rapiba** - Master-Verwaltungsscript

### Dokumentation
- **README.md** - Hauptdokumentation
- **TROUBLESHOOTING.md** - Häufige Probleme & Lösungen
- **PERFORMANCE.md** - Performance-Tuning Guide
- **EXAMPLES.conf** - Konfigurationsbeispiele
- **PROJECT_SUMMARY.md** - Projektübersicht
- **user_guide.py** - Interaktives Benutzer-Tutorial

### Tests
- **test_rapiba.py** - Unit Tests für alle Komponenten

---

## 🚀 Quick Start (Raspberry Pi)

### Schritt 1: Installation
```bash
cd rapiba
sudo bash install.sh
```

### Schritt 2: Schnelle Konfiguration
```bash
sudo bash quicksetup.sh
```
Wähle eines von 4 vordefinierten Szenarien:
1. Standard (Datum & Nummer, SHA256)
2. Schnell (Nummer, size_time)
3. Sicher (SHA256 mit Verifikation)
4. Custom (eigene Einstellungen)

### Schritt 3: Verifikation
```bash
sudo bash verify_installation.sh
```

### Schritt 4: Service starten
```bash
sudo systemctl start rapiba
sudo systemctl enable rapiba
```

### Schritt 5: Testen
```bash
rapiba --list-devices
rapiba --backup-now
journalctl -u rapiba -f
```

---

## 🎯 Kernfeatures

| Feature | Beschreibung | Status |
|---------|-------------|--------|
| USB-Erkennung | Automatisches Erkennen beim Anstecken | ✅ |
| SD-Card-Erkennung | Unterstützung für SD-Cards | ✅ |
| Duplikat-Vermeidung | MD5/SHA256/size_time | ✅ |
| Flexible Pfade | Datum/Nummer/kombiniert/custom | ✅ |
| Paralleles Kopieren | Configurable Thread-Pool | ✅ |
| Umfassendes Logging | Datei + systemd-Logs | ✅ |
| Konfigurierbar | 40+ Optionen | ✅ |
| Auto-Cleanup | Alte Backups löschen | ✅ |
| Geplante Backups | systemd Timer | ✅ |
| Admin-Tool | Statistiken & Management | ✅ |

---

## 📁 Konfigurationsoptionen (mit Defaults)

```ini
# Quellen & Ziele
BACKUP_SOURCES=/media/usb,/media/sdcard
BACKUP_TARGET=/backup

# Pfad-Format
BACKUP_PATH_FORMAT=both  # datetime, number, both, custom
CUSTOM_PATH_FORMAT=      # nur bei custom

# Duplikat-Erkennung
DUPLICATE_CHECK_METHOD=sha256  # md5, sha256, size_time, none
DUPLICATE_DB_PATH=/var/lib/rapiba/duplicate_db.sqlite3

# Logging
LOG_DIR=/var/log/rapiba
LOG_LEVEL=INFO

# Performance
PARALLEL_JOBS=2
COMPRESS_BACKUPS=no

# Speicher
DELETE_OLD_BACKUPS_DAYS=0
MAX_BACKUPS_PER_SOURCE=0

# Sicherheit
BACKUP_DIR_MODE=755
BACKUP_FILE_MODE=644
VERIFY_CHECKSUMS=yes

# Development
DRY_RUN=no
```

---

## 📊 Verwendungsbeispiele

### Beispiel 1: Einfaches tägliches Backup
```ini
BACKUP_PATH_FORMAT=datetime
DUPLICATE_CHECK_METHOD=sha256
```
Ergebnis: `/backup/2025-11-14_10-30-45/`

### Beispiel 2: Nummeriert mit Auto-Cleanup
```ini
BACKUP_PATH_FORMAT=number
DELETE_OLD_BACKUPS_DAYS=30
MAX_BACKUPS_PER_SOURCE=10
```
Ergebnis: `/backup/backup_1/`, `/backup/backup_2/`, etc.

### Beispiel 3: Nach Datum & Quelle organisiert
```ini
BACKUP_PATH_FORMAT=custom
CUSTOM_PATH_FORMAT={date}/{source}_{number}
```
Ergebnis: `/backup/2025-11-14/usb_1/`, `/backup/2025-11-14/sdcard_1/`, etc.

### Beispiel 4: Schnelle Backups
```ini
DUPLICATE_CHECK_METHOD=size_time
PARALLEL_JOBS=4
VERIFY_CHECKSUMS=no
```
→ Bis zu 50% schneller

---

## 🛠️ Häufige Befehle

```bash
# Service Management
sudo systemctl start rapiba
sudo systemctl stop rapiba
sudo systemctl status rapiba
sudo systemctl restart rapiba
sudo systemctl enable rapiba

# Manuelle Backups
rapiba --backup-now
rapiba --backup-now /media/usb

# Information
rapiba --list-devices
rapiba --list-backups

# Logs
journalctl -u rapiba -f
tail -f /var/log/rapiba/*.log

# Admin
rapiba_admin --stats
rapiba_admin --db-stats
rapiba_admin --clean 30
rapiba_admin --reset-db

# Konfiguration
nano /etc/rapiba/rapiba.conf
sudo systemctl restart rapiba

# Verifikation
verify_installation.sh
```

---

## ⚙️ Performance-Tipps

### Für Raspberry Pi Zero (Single-Core)
```ini
PARALLEL_JOBS=1
DUPLICATE_CHECK_METHOD=size_time
VERIFY_CHECKSUMS=no
```

### Für Raspberry Pi 3/3B+ (Quad-Core)
```ini
PARALLEL_JOBS=2
DUPLICATE_CHECK_METHOD=md5
VERIFY_CHECKSUMS=no
```

### Für Raspberry Pi 4 (Quad-Core, 4GB+)
```ini
PARALLEL_JOBS=4
DUPLICATE_CHECK_METHOD=sha256
VERIFY_CHECKSUMS=yes
```

---

## 🔍 Troubleshooting Quick Links

**Backups werden nicht automatisch gestartet?**
→ Siehe TROUBLESHOOTING.md, Problem 1

**Sehr langsame Backups?**
→ PERFORMANCE.md - Performance-Tipps

**Berechtigungsfehler?**
→ TROUBLESHOOTING.md, Problem 2

**Duplikate nicht erkannt?**
→ TROUBLESHOOTING.md, Problem 3

**Vollständig gefüllter Speicher?**
→ TROUBLESHOOTING.md, Problem 4

---

## 📚 Weitere Ressourcen

| Datei | Zweck |
|-------|-------|
| README.md | Übersicht & Feature-Liste |
| TROUBLESHOOTING.md | Probleme & Lösungen |
| PERFORMANCE.md | Performance-Optimierung |
| EXAMPLES.conf | Config-Beispiele |
| PROJECT_SUMMARY.md | Technische Details |
| user_guide.py | Interaktives Tutorial |

Interaktives Tutorial starten:
```bash
python3 user_guide.py
```

---

## 📋 Dateistruktur nach Installation

```
/etc/rapiba/
  └── rapiba.conf              # Deine Konfiguration

/usr/local/bin/
  ├── rapiba                   # Hauptcommand
  ├── rapiba_monitor           # Monitoring-Daemon
  └── rapiba_trigger           # udev-Trigger

/usr/local/lib/rapiba/
  ├── backup_handler.py        # Kern-Modul
  ├── rapiba_monitor.py        # Monitor
  ├── rapiba_trigger.py        # Trigger
  └── rapiba_admin.py          # Admin-Tool

/var/lib/rapiba/
  └── duplicate_db.sqlite3     # Duplikat-Datenbank

/var/log/rapiba/
  ├── rapiba_YYYY-MM-DD.log    # Tägliche Logs
  ├── monitor_YYYY-MM-DD.log   # Monitor-Logs
  └── trigger.log              # Trigger-Logs

/backup/                       # Deine Backups
  ├── backup_1_2025-11-14_10-30-45/
  ├── backup_2_2025-11-14_15-22-10/
  └── ...
```

---

## 🔐 Sicherheits-Hinweise

1. **Berechtigungen**: Rapiba läuft als root (notwendig für udev)
2. **Keine Verschlüsselung**: Nutze LUKS/EncFS für sensitive Backups
3. **Logs enthalten Pfade**: Behandle `/var/log/rapiba/` wie sensitive Dateien
4. **Backup-Verzeichnis-Zugriff**: Nur root kann durch Standard-Konfiguration darauf zugreifen

---

## 🎓 Lernressourcen

1. **Anfänger**: Starten mit `python3 user_guide.py`
2. **Installation**: Folge den 5 Quick-Start Schritten oben
3. **Troubleshooting**: Sieh TROUBLESHOOTING.md
4. **Performance**: Sieh PERFORMANCE.md
5. **Entwicklung**: Sieh Quellcode-Kommentare in backup_handler.py

---

## ✨ Zusammenfassung

Mit diesem System kannst du:

✅ USB-Sticks & SD-Cards **automatisch** sichern  
✅ Backups **organisieren** (Datum, Nummer, Custom)  
✅ **Duplikate vermeiden** (3 verschiedene Methoden)  
✅ **Parallel kopieren** für schnellere Backups  
✅ **Alte Backups** automatisch löschen  
✅ Alles über eine **Konfigurationsdatei** steuern  
✅ **Systemd integriert** - läuft im Hintergrund  
✅ **Umfangreiche Logs** für Debugging  

---

## 🚦 Nächste Schritte

1. **Installieren**: `sudo bash install.sh`
2. **Konfigurieren**: `sudo bash quicksetup.sh`
3. **Verifizieren**: `sudo bash verify_installation.sh`
4. **Starten**: `sudo systemctl start rapiba`
5. **Testen**: USB-Stick anstecken und Logs beobachten

Viel Erfolg! 🎉

---

**Version**: 1.0.0  
**Erstellt**: November 14, 2025  
**Support**: Siehe TROUBLESHOOTING.md
