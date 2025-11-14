# Rapiba - Automated Raspberry Pi Backup System


Ein automatisches Backup-System für Raspberry Pi, das USB-Sticks und SD-Cards erkennt und deren Inhalte automatisch sichert.

## Features

✅ **Automatische Geräteerkennung** - Erkennt USB-Sticks und SD-Cards automatisch beim Anstecken  
✅ **Duplikat-Vermeidung** - MD5, SHA256 oder Dateigröße/Zeit-basierte Duplikat-Erkennung  
✅ **Flexible Pfadstruktur** - Datum, Nummer oder kombiniert als Backup-Verzeichnis  
✅ **Paralleles Kopieren** - Mehrere Dateien gleichzeitig kopieren  
✅ **Umfassendes Logging** - Detaillierte Logs aller Operationen  
✅ **Konfigurierbar** - Alles über `/etc/rapiba/rapiba.conf`  
✅ **systemd Integration** - Läuft als Systemdienst  
✅ **udev Integration** - Triggert automatisch bei Geräteerkennung  

## Anforderungen

- **Python 3.6+** (siehe [PYTHON_REQUIREMENTS.md](PYTHON_REQUIREMENTS.md))
- Raspberry Pi mit Raspbian/Debian oder ähnlich
- Root-Zugriff für Installation
- ~20 MB freier Speicher

Siehe `check_python_requirements.sh` zur Überprüfung der Python-Installation.

## Installation

### Voraussetzungen

- Raspberry Pi mit Raspbian/Debian Linux
- Python 3.6 oder höher
- Root-Zugriff für Installation

### Quick Start

```bash
# Repository klonen
git clone https://github.com/yourusername/rapiba.git
cd rapiba

# Installation durchführen
sudo bash install.sh

# Konfiguration anpassen
sudo nano /etc/rapiba/rapiba.conf

# Service starten
sudo systemctl start rapiba
sudo systemctl enable rapiba
```

## Konfiguration

Die Hauptkonfiguration befindet sich unter `/etc/rapiba/rapiba.conf`:

### Wichtige Parameter

```ini
# Zu sichernde Verzeichnisse
BACKUP_SOURCES=/media/usb,/media/sdcard

# Zielverzeichnis für Backups
BACKUP_TARGET=/backup

# Format des Backup-Pfades
BACKUP_PATH_FORMAT=both  # datetime, number, both, custom
CUSTOM_PATH_FORMAT={date}_backup_{number}  # nur bei custom

# Duplikat-Erkennung: md5, sha256, size_time, none
DUPLICATE_CHECK_METHOD=sha256

# Parallele Kopier-Jobs
PARALLEL_JOBS=2

# Dry-Run Modus (simuliert ohne zu kopieren)
DRY_RUN=no
```

## Bedienung

### Backup sofort starten

```bash
# Alle konfigurierten Quellen
sudo rapiba --backup-now

# Spezifische Quelle
sudo rapiba --backup-now /media/usb
```

### Erkannte Geräte anzeigen

```bash
sudo rapiba --list-devices
```

### Backups auflisten

```bash
sudo rapiba --list-backups
```

### Service verwalten

```bash
# Status prüfen
systemctl status rapiba

# Logs anzeigen
journalctl -u rapiba -f

# Service neu starten
systemctl restart rapiba

# Service stoppen
systemctl stop rapiba
```

### Werkseinstellung zurücksetzen

```bash
# Alle gespeicherten Daten löschen (Factory Reset)
sudo rapiba --factory-reset
```

⚠️ **WARNUNG**: Dies löscht:
- Duplikat-Datenbank (`/var/lib/rapiba/`)
- Alle Log-Dateien (`/var/log/rapiba/`)
- Alle Backups (`/backup/`)
- Konfiguration (wird auf Werkseinstellungen zurückgesetzt)

Dies kann **NICHT rückgängig gemacht werden**!

## Backup-Pfad Formate

### datetime
Verwendet aktuelles Datum und Uhrzeit:
```
/backup/2025-11-14_10-30-45/
```

### number
Laufende Nummer:
```
/backup/backup_1/
/backup/backup_2/
/backup/backup_3/
```

### both (empfohlen)
Kombiniert beide:
```
/backup/backup_1_2025-11-14_10-30-45/
/backup/backup_2_2025-11-14_10-35-22/
```

### custom
Eigenes Format mit Variablen:
```
CUSTOM_PATH_FORMAT={date}_backup_{number}_{source}
# Ergebnis: /backup/2025-11-14_backup_1_usb/
```

Verfügbare Variablen:
- `{datetime}` - YYYY-MM-DD_HH-MM-SS
- `{date}` - YYYY-MM-DD
- `{time}` - HH-MM-SS
- `{number}` - Laufende Nummer
- `{source}` - Gerätename (z.B. 'usb', 'sdcard')

## Duplikat-Erkennung

Das System verhindert Duplikate durch verschiedene Methoden:

### SHA256 (Standard, empfohlen)
- Prüft SHA256-Checksumme der kompletten Datei
- Sicherste Methode, aber langsamer bei großen Dateien
- Ideal für wichtige Daten

### MD5
- Schneller als SHA256
- Weniger sicher (theoretisch anfällig für Kollisionen)
- Guter Kompromiss zwischen Geschwindigkeit und Sicherheit

### size_time
- Vergleicht nur Dateigröße und Änderungszeit
- Schnellste Methode
- Anfällig für falsche Positive

### none
- Keine Duplikat-Erkennung
- Dateien werden immer überschrieben
- Schnellste Option

## Logging

Logs befinden sich unter `/var/log/rapiba/`:

```bash
# Echtzeit-Logs ansehen
tail -f /var/log/rapiba/rapiba_*.log

# Nur heute
tail -f /var/log/rapiba/rapiba_$(date +%Y-%m-%d).log

# Nur Fehler
grep ERROR /var/log/rapiba/rapiba_*.log
```

## Duplikat-Datenbank

Die Datenbank der kopierten Dateien befindet sich unter:
```
/var/lib/rapiba/duplicate_db.sqlite3
```

Zum Inspizieren:
```bash
sqlite3 /var/lib/rapiba/duplicate_db.sqlite3
sqlite> SELECT * FROM file_hashes;
sqlite> .mode column
sqlite> .headers on
```

## Beispiel-Szenarien

### Szenario 1: Regelmäßiges Backup mit Datum

```ini
BACKUP_TARGET=/backup/external_drive
BACKUP_PATH_FORMAT=datetime
DUPLICATE_CHECK_METHOD=sha256
PARALLEL_JOBS=4
```

Ergebnis:
```
/backup/external_drive/2025-11-14_10-30-45/
/backup/external_drive/2025-11-14_11-15-22/
```

### Szenario 2: Nummeriertes Backup mit Duplikat-Vermeidung

```ini
BACKUP_TARGET=/backup/sd_card_backup
BACKUP_PATH_FORMAT=number
DUPLICATE_CHECK_METHOD=sha256
DELETE_OLD_BACKUPS_DAYS=30
MAX_BACKUPS_PER_SOURCE=10
```

Ergebnis:
```
/backup/sd_card_backup/backup_1/
/backup/sd_card_backup/backup_2/
/backup/sd_card_backup/backup_3/
(alte werden gelöscht wenn älter als 30 Tage oder mehr als 10 Backups)
```

### Szenario 3: Orga nach Datum und Gerät

```ini
BACKUP_PATH_FORMAT=custom
CUSTOM_PATH_FORMAT={date}/{source}_backup_{number}
```

Ergebnis:
```
/backup/2025-11-14/usb_backup_1/
/backup/2025-11-14/sdcard_backup_1/
/backup/2025-11-15/usb_backup_2/
```

## Troubleshooting

### Werkseinstellung zurücksetzen (Factory Reset)

Falls du Rapiba komplett neu aufsetzen möchtest:

```bash
sudo rapiba --factory-reset
```

Dies wird:
1. ✓ Den Service stoppen
2. ✓ Die Duplikat-Datenbank löschen
3. ✓ Alle Log-Dateien löschen
4. ✓ Das Backup-Verzeichnis löschen
5. ✓ Die Konfiguration zurücksetzen (auf Werkseinstellungen)
6. ✓ Die Standard-Konfiguration wiederherstellen
7. ✓ Den Service neu starten

**Das System ist dann wie nach der Installation - vollständig leer.**

**Wichtig**: Die Bestätigung erfordert zweifache Eingabe zum Schutz vor Unfällen.

### Backups werden nicht automatisch gestartet

1. Prüfe ob Service läuft:
```bash
systemctl status rapiba
```

2. Prüfe Logs:
```bash
journalctl -u rapiba -n 50
```

3. Prüfe udev Rules:
```bash
udevadm monitor --property
# Stecke USB-Stick ein und prüfe ob Events kommen
```

### Duplikate werden nicht erkannt

1. Prüfe ob Datenbank existiert:
```bash
ls -la /var/lib/rapiba/duplicate_db.sqlite3
```

2. Prüfe Config-Setting:
```bash
grep DUPLICATE_CHECK_METHOD /etc/rapiba/rapiba.conf
```

3. Setze Datenbank zurück (löscht Duplikat-Verlauf):
```bash
rm /var/lib/rapiba/duplicate_db.sqlite3
systemctl restart rapiba
```

### Backup läuft zu langsam

1. Erhöhe PARALLEL_JOBS in Config
2. Schalte Checksummen-Verifikation aus: `VERIFY_CHECKSUMS=no`
3. Nutze schnellere Duplikat-Methode: `DUPLICATE_CHECK_METHOD=size_time`

### Berechtigungsfehler

```bash
# Stelle sicher dass /backup beschreibbar ist
sudo chmod 755 /backup
sudo chown root:root /backup

# Und das Backup-Verzeichnis
sudo chown -R root:root /var/lib/rapiba
sudo chmod -R 755 /var/lib/rapiba
```

## Architektur

```
Rapiba System
├── backup_handler.py (Kern-Modul)
│   ├── Config (Konfiguration)
│   ├── RapibaLogger (Logging)
│   ├── DuplicateDB (SQLite Duplikat-DB)
│   ├── FileHash (Hash-Berechnung)
│   ├── BackupPathGenerator (Pfad-Generierung)
│   ├── BackupEngine (Kopier-Logik)
│   └── DeviceDetector (USB/SD-Card Erkennung)
│
├── rapiba_monitor.py (Daemon)
│   └── Überwacht kontinuierlich auf neue Geräte
│
├── rapiba_trigger.py (udev Trigger)
│   └── Wird von udev aufgerufen
│
└── Konfiguration
    └── /etc/rapiba/rapiba.conf
```

## Entwicklung

### Struktur

```
rapiba/
├── src/
│   ├── backup_handler.py      (Hauptmodul)
│   ├── rapiba_monitor.py      (Monitor-Daemon)
│   └── rapiba_trigger.py      (udev-Trigger)
├── etc/
│   └── rapiba.conf            (Standard-Config)
├── systemd/
│   └── rapiba.service         (systemd Service)
├── udev/
│   └── 99-rapiba.rules        (udev Rules)
├── install.sh                 (Installer)
└── README.md                  (Diese Datei)
```

### Erweiterungen

Um eigene Features hinzuzufügen:

1. Bearbeite `src/backup_handler.py`
2. Oder erstelle neues Modul in `src/`
3. Integriere in `rapiba_monitor.py` oder `backup_handler.py`
4. Test mit `--dry-run`

## Lizenz

MIT License

## Support

Für Issues und Feature-Requests bitte ein GitHub Issue erstellen.

## Änderungslog

### v1.0.0 (2025-11-14)
- Initial Release
- Automatische USB/SD-Card Erkennung
- SHA256/MD5/size_time Duplikat-Erkennung
- Flexible Pfad-Formate
- systemd und udev Integration
