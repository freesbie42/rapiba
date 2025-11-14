# Rapiba - Automatische Geräte-Erkennung

## Übersicht

Das Rapiba-System erkennt automatisch **ALLE** angesteckten Speichergeräte, unabhängig davon:
- Wo sie gemountet sind (`/media`, `/mnt`, `/run/media`, etc.)
- Wie sie heißen (USB-Stick, SD-Karte, externe Festplatte, etc.)
- Welches Dateisystem sie haben (ext4, vfat, exfat, ntfs, etc.)

## Wie es funktioniert

### 1. Mount-Punkt-Scanning

Das System liest `/proc/mounts` um alle aktuell eingehängten Dateisysteme zu finden:

```
/proc/mounts (Linux)
  ↓
DeviceDetector._read_mounts()
  ↓
Parse all mount entries
  ↓
Filter und Validierung
```

### 2. Intelligente Filterung

Folgende Dateisysteme werden **AUSGESCHLOSSEN**:
- **Systemdateisysteme**: tmpfs, sysfs, devtmpfs, proc, cgroup, etc.
- **ISO/Loop-Geräte**: iso9660, loop (CD/DVD)
- **Pseudo-Dateisysteme**: securityfs, debugfs, tracefs, etc.

Folgende Dateisysteme werden **AKZEPTIERT**:
- **Speichermedien**: ext4, ext3, ext2, vfat, exfat, ntfs, ntfs-3g, btrfs, xfs, f2fs, msdos

### 3. System-Pfade ausschließen

Automatisch ausgeschlossene Verzeichnisse:
```
/ /boot /sys /proc /dev /run /tmp /var /etc /usr /bin /sbin /lib /opt
```

Das verhindert, dass Systempartitionen als "neue Geräte" erkannt werden.

### 4. Backup-Ziel-Ausschluss

**KRITISCHE FEATURE**: Das Backup-Ziel wird automatisch ausgeschlossen!

Dies ist wichtig wenn das Backup auf einem externen Medium gespeichert wird:

```
Beispiel:
  USB-Stick 1 (Device A) gemountet als /media/usb1 → wird gesichert
  USB-Stick 2 (Device B) gemountet als /mnt/backup → wird AUSGESCHLOSSEN
                                                      (ist BACKUP_TARGET)
```

Das verhindert Endlosschleifen beim Backup-zu-Backup-Kopieren.

## Konfiguration

### Hauptkonfigurationsdatei: `/etc/rapiba/rapiba.conf`

```ini
# Backup-Ziel (wird automatisch von der Erkennung ausgeschlossen)
BACKUP_TARGET=/mnt/external_backup

# Nicht mehr nötig! BACKUP_SOURCES wird automatisch ermittelt:
# BACKUP_SOURCES wird ignoriert (legacy support entfernt)
```

### Relevante Parameter

```ini
# Intervall zwischen Device-Checks (in Sekunden)
DEVICE_CHECK_INTERVAL=5

# Log-Level für ausführlichere Diagnostik
LOG_LEVEL=DEBUG

# Backup-Optionen
PARALLEL_JOBS=4
DUPLICATE_CHECK_METHOD=sha256
BACKUP_PATH_FORMAT=both
```

## Erkennung in Aktion

### Monitor-Modus (`rapiba_monitor.py`)

Läuft als systemd-Service und prüft alle 5 Sekunden auf neue Geräte:

```bash
$ sudo systemctl start rapiba
$ sudo journalctl -u rapiba -f

# Beispiel-Output:
============================================================
Rapiba Monitor - Automatische Geräte-Erkennung
============================================================
Device-Check-Intervall: 5s
Backup-Ziel: /mnt/external_backup
Backup-Ziel wird automatisch ausgeschlossen
Warte auf neue Speichergeräte...

[USB-Stick wird angesteckt]

============================================================
🔌 1 neue(s) Gerät(e) erkannt!
============================================================
Starte Backup für: /media/usb
✅ Backup erfolgreich für /media/usb
============================================================
```

### Trigger-Modus (`rapiba_trigger.py`)

Wird zusätzlich durch udev-Rules aufgerufen wenn Geräte angesteckt werden:

```bash
$ tail -f /var/log/rapiba/trigger.log

# Beispiel:
2024-01-15 14:22:45 INFO: Trigger aufgerufen mit DEVNAME=/dev/sda1
2024-01-15 14:22:46 INFO: 🔌 1 Gerät(e) erkannt
2024-01-15 14:22:46 INFO: → Backup von /media/external läuft...
2024-01-15 14:22:52 INFO: ✅ Backup erfolgreich
```

## Geräte-Anschluss-Szenarios

### Szenario 1: USB-Stick automatisch gemountet

```
User steckt USB-Stick an
  ↓
Auto-Mount durch Linux
  ↓
udev rule triggert rapiba_trigger
  ↓
DeviceDetector findet /media/usb
  ↓
Backup wird automatisch gestartet
```

### Szenario 2: Mehrere Geräte gleichzeitig

```
Geräte angesteckt:
  - /media/disk1
  - /mnt/usb_stick
  - /run/media/user/sdcard

DeviceDetector erkennt alle:
  ✓ /media/disk1      (ext4, Speichermedium)
  ✓ /mnt/usb_stick    (vfat, USB-Stick)
  ✓ /run/media/user/sdcard (exfat, SD-Karte)
  
  ✗ /boot             (ausgeschlossen - Systempfad)
  ✗ /sys              (ausgeschlossen - sysfs)
  ✗ /mnt/backup       (ausgeschlossen - ist BACKUP_TARGET)
```

### Szenario 3: Backup auf externem Medium

```
Konfiguration:
  BACKUP_TARGET=/mnt/backup_disk

Angesteckte Geräte:
  - /media/usb1      → Backup wird erstellt → /mnt/backup_disk/backup_001_...
  - /mnt/backup_disk → wird AUSGESCHLOSSEN (ist Backup-Ziel!)
```

## API-Nutzung für Entwickler

### Device-Erkennung durchführen

```python
from backup_handler import Config, DeviceDetector

config = Config('/etc/rapiba/rapiba.conf')
detector = DeviceDetector(config, logger)

# Alle Speichergeräte erkunden
devices = detector.detect_devices()
# → ['/media/usb', '/mnt/external', '/run/media/user/sdcard']

# Backup-Ziel wird automatisch ausgeschlossen!
```

### Neue Geräte seit letzter Überprüfung

```python
# Bekannte Geräte vom letzten Check
known = ['/media/usb']

# Neue Geräte finden
new = detector.find_new_devices(known)
# → ['/mnt/external']  (wenn angesteckt)
```

### Entfernte Geräte erkennen

```python
known = ['/media/usb', '/mnt/external']

removed = detector.find_removed_devices(known)
# → ['/mnt/external']  (wenn entfernt)
```

## Diagnostik

### Manuell Geräte auflisten

```bash
$ python3 /usr/local/lib/rapiba/backup_handler.py --list-devices

Rapiba - Automated Raspberry Pi Backup
============================================================
Erkannte Geräte: /media/usb, /mnt/external, /run/media/user/sdcard
  - /media/usb
  - /mnt/external
  - /run/media/user/sdcard
```

### Debug-Logging aktivieren

```bash
# Bearbeite /etc/rapiba/rapiba.conf
LOG_LEVEL=DEBUG

# Monitor starten mit mehr Ausgabe
$ sudo systemctl start rapiba
$ sudo journalctl -u rapiba -f

# Sieht zusätzliche Debug-Meldungen:
# - Alle gescannten Mount-Punkte
# - Warum Dateisysteme ausgeschlossen werden
# - Real-Path-Auflösung für Backup-Ziel
```

### Manueller Test der Erkennung

```bash
# Im Python-Interpreter
$ python3
>>> from backup_handler import Config, DeviceDetector, RapibaLogger
>>> config = Config('/etc/rapiba/rapiba.conf')
>>> logger = RapibaLogger(config).get_logger()
>>> detector = DeviceDetector(config, logger)
>>> devices = detector.detect_devices()
>>> for d in devices:
...     print(f"Gerät: {d}")
```

## Besonderheiten und Edge-Cases

### Symlinks

Das System konvertiert alle Pfade zu realen Pfaden:

```
/media/usb → symlink → /mnt/actual_device
               ↓
         os.path.realpath()
               ↓
         /mnt/actual_device (wird gespeichert)
```

Dies verhindert Duplikate wenn das gleiche Gerät über mehrere Pfade erreichbar ist.

### Backup-Ziel als Symlink

```
BACKUP_TARGET=/mnt/backup → symlink → /media/external

DeviceDetector wird das richtig erkennen und ausschließen:
  /media/usb         → wird gesichert
  /media/external    → wird AUSGESCHLOSSEN (=BACKUP_TARGET)
```

### Escaped Zeichen in Mount-Pfaden

Pfade mit Leerzeichen oder Sonderzeichen werden automatisch dekodiert:

```
/proc/mounts:  /dev/sda1 /mnt/device\040name vfat ...
                                  ^^^^
                            (Leerzeichen in Oktal)
               ↓
      /mnt/device name (wird korrekt dekodiert)
```

## Performance

- **Scan-Zeit**: Typisch < 100ms (für 50+ Dateisysteme)
- **CPU-Last**: Minimal (nur Datei-Lesen aus /proc/mounts)
- **Memory**: < 10MB (wird schnell freigegeben)

## Sicherheit

1. **Keine Erhöhung von Berechtigungen**: udev Rules laufen mit normalen Berechtigungen
2. **Backup-Ziel-Schutz**: Verhindert versehentliches Überschreiben
3. **Berechtigungsprüfung**: Nur lesbare Verzeichnisse werden berücksichtigt
4. **Logging**: Alle Aktionen werden protokolliert

## Troubleshooting

### Problem: Gerät wird nicht erkannt

```bash
# 1. Prüfe Mounting
$ mount | grep -E 'media|mnt'
/dev/sda1 on /media/usb type vfat

# 2. Prüfe /proc/mounts
$ cat /proc/mounts | grep -E 'media|mnt'

# 3. Starte Monitor mit Debug
LOG_LEVEL=DEBUG systemctl restart rapiba
journalctl -u rapiba -f

# 4. Manueller Test
$ python3 /usr/local/lib/rapiba/backup_handler.py --list-devices
```

### Problem: Falsches Gerät wird ausgeschlossen

```bash
# Prüfe BACKUP_TARGET in Config
$ grep "^BACKUP_TARGET" /etc/rapiba/rapiba.conf

# Prüfe Real-Path des Backup-Ziels
$ ls -la /mnt/backup_disk
# Sollte keine Symlinks sein oder auf das richtige Gerät zeigen
```

### Problem: Zu viele Geräte werden erkannt

```bash
# Increase Log Level zu DEBUG
# Prüfe welche Dateisysteme erkannt werden
$ cat /proc/mounts | awk '{print $3}' | sort | uniq -c

# Falls unerwartete Dateisysteme dabei sind,
# können diese in SYSTEM_FILESYSTEMS oder REMOVABLE_FILESYSTEMS
# in der DeviceDetector-Klasse angepasst werden.
```

## Weitere Ressourcen

- `backup_handler.py` - DeviceDetector Klasse (Zeilen 447-600)
- `rapiba_monitor.py` - Daemon für kontinuierliche Überwachung
- `rapiba_trigger.py` - udev-Trigger für sofortige Erkennung
- `/etc/rapiba/rapiba.conf` - Konfigurationsdatei
