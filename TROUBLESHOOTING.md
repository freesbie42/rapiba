# Rapiba - Troubleshooting Guide

## Problem: Backups werden nicht automatisch gestartet

### Symptom
Nach Einstecken von USB-Stick/SD-Card wird kein Backup gestartet.

### Lösungsschritte

1. **Prüfe ob Service läuft**
```bash
systemctl status rapiba
```

Erwartet: `active (running)`

Falls nicht, starte ihn:
```bash
sudo systemctl start rapiba
sudo systemctl enable rapiba
```

2. **Prüfe Logs**
```bash
journalctl -u rapiba -n 50 -f
```

Suche nach Fehlern. Häufige Fehler:
- "Could not find module..." → Python-Module nicht installiert
- "Permission denied" → Berechtigungsproblem
- "No such file or directory" → Pfad existiert nicht

3. **Prüfe udev Rules**
```bash
# Logs der udev-Rules
journalctl -n 50 | grep "rapiba_trigger"

# Manual trigger test
udevadm monitor --property &
# Stecke USB-Stick ein und beobachte Ausgabe
```

Falls keine Events: Hardware-Erkennung Problem

4. **Prüfe Konfiguration**
```bash
cat /etc/rapiba/rapiba.conf | grep -E "^[^#]"
```

Stelle sicher dass:
- BACKUP_SOURCES Verzeichnisse existieren oder sind automountable
- BACKUP_TARGET Verzeichnis existiert und schreibbar ist

5. **Test mit manuelles Backup**
```bash
sudo rapiba --backup-now /media/usb
```

Falls das funktioniert: Problem ist die automatische Erkennung
Falls das nicht funktioniert: Problem ist das Backup-System selbst

---

## Problem: "Permission denied" Fehler

### Symptom
```
ERROR: Permission denied when copying...
```

### Lösungen

1. **Prüfe ob Zielverzeichnis schreibbar ist**
```bash
ls -la /backup
# Sollte: drwxr-xr-x root root sein
```

Falls nicht:
```bash
sudo chmod 755 /backup
sudo chown root:root /backup
```

2. **Prüfe Berechtigungen der Datenbank**
```bash
ls -la /var/lib/rapiba/
sudo chmod 755 /var/lib/rapiba
```

3. **Prüfe Berechtigungen der Log-Dateien**
```bash
ls -la /var/log/rapiba/
sudo chmod 755 /var/log/rapiba
```

4. **Prüfe Quellverzeichnis-Berechtigungen**
```bash
ls -la /media/usb
# Sollte lesbar sein
```

---

## Problem: Duplikate werden nicht erkannt

### Symptom
Dateien werden jedes Mal erneut kopiert, obwohl sie unverändert sind.

### Lösungsschritte

1. **Prüfe Config-Einstellung**
```bash
grep DUPLICATE_CHECK_METHOD /etc/rapiba/rapiba.conf
```

Sollte nicht "none" sein.

2. **Prüfe Datenbank existiert**
```bash
ls -la /var/lib/rapiba/duplicate_db.sqlite3
```

Falls nicht vorhanden:
```bash
sudo touch /var/lib/rapiba/duplicate_db.sqlite3
sudo chmod 644 /var/lib/rapiba/duplicate_db.sqlite3
```

3. **Datenbank zurücksetzen**
Das löscht den Duplikat-Verlauf, aber behebt das Problem:
```bash
sudo rm /var/lib/rapiba/duplicate_db.sqlite3
sudo systemctl restart rapiba
```

4. **Prüfe ob Dateien wirklich identisch sind**
```bash
# MD5-Hash von Originalquelle
md5sum /media/usb/testfile.txt

# MD5-Hash im Backup
md5sum /backup/backup_1/testfile.txt

# Falls unterschiedlich: Datei wird jedes Mal modifiziert
```

5. **Nutze schnellere Duplikat-Methode**
Falls SHA256 zu langsam ist:
```ini
DUPLICATE_CHECK_METHOD=md5  # oder size_time
```

---

## Problem: Backup dauert zu lange

### Symptom
Backup von z.B. 10GB dauert 2+ Stunden

### Optimierungen

1. **Erhöhe Parallel-Jobs**
```ini
PARALLEL_JOBS=4  # Für Quad-Core
```

Dann Service neu starten:
```bash
sudo systemctl restart rapiba
```

2. **Nutze schnellere Duplikat-Methode**
```ini
DUPLICATE_CHECK_METHOD=size_time  # statt sha256
```

3. **Deaktiviere Checksummen-Verifikation**
```ini
VERIFY_CHECKSUMS=no
```

4. **Nutze Compression**
Falls Speicher Bottleneck ist:
```ini
COMPRESS_BACKUPS=yes
COMPRESSION_LEVEL=6
```

5. **Prüfe Hardware-Bottleneck**
```bash
# Während Backup läuft in anderem Terminal:
iostat -x 1
```

Falls Wait-I/O % sehr hoch: Disk ist Bottleneck, nicht viel zu machen

Prüfe auch:
- USB-Stick ist schnell genug (mindestens USB 3.0)
- SD-Card ist Class 10 / U3
- Raspberry Pi hat gutes Netzteil (2.5A+ für Pi 4)

---

## Problem: "No space left on device"

### Symptom
Backup startet aber bricht mit Speicherfehler ab.

### Lösungen

1. **Prüfe verfügbaren Speicher**
```bash
df -h
```

Stelle sicher dass BACKUP_TARGET genug Platz hat.

2. **Aktiviere automatische Cleanup**
```ini
DELETE_OLD_BACKUPS_DAYS=30
MAX_BACKUPS_PER_SOURCE=5
```

```bash
sudo systemctl restart rapiba
```

3. **Manuell alte Backups löschen**
```bash
ls -la /backup | sort
sudo rm -rf /backup/backup_1  # ältestes löschen
```

4. **Prüfe ob kompression hilft**
```ini
COMPRESS_BACKUPS=yes
```

---

## Problem: Service startet nicht nach Boot

### Symptom
Nach Neustart des Pi läuft rapiba nicht.

### Lösungen

1. **Prüfe ob autostart aktiviert ist**
```bash
systemctl is-enabled rapiba
```

Falls `disabled`:
```bash
sudo systemctl enable rapiba
```

2. **Prüfe Startup-Fehler**
```bash
sudo systemctl restart rapiba
journalctl -u rapiba -n 20
```

Häufige Fehler:
- Config-Datei nicht gefunden
- Python-Module nicht vorhanden
- Abhängige Verzeichnisse existieren nicht

3. **Prüfe Abhängigkeiten**
```ini
# In rapiba.service muss stehen:
After=network-online.target
Wants=network-online.target
```

---

## Problem: Hohe CPU-Last

### Symptom
Raspberry Pi bleibt stehen während Backup läuft (andere Prozesse reagieren nicht)

### Lösungen

1. **Reduziere Parallel-Jobs**
```ini
PARALLEL_JOBS=1  # statt 4
```

2. **Nutze schnellere Duplikat-Methode**
```ini
DUPLICATE_CHECK_METHOD=size_time  # statt sha256
```

3. **Planen Sie Backups zu Off-Peak-Zeiten**
Mit systemd Timer:
```bash
sudo systemctl enable rapiba-backup.timer
```

Editiere `/etc/systemd/system/rapiba-backup.timer`:
```ini
OnCalendar=*-*-* 02:00:00  # 2 Uhr nachts
```

4. **Nutze CPU-Frequenzskalierung**
```bash
# Prüfe aktuelle Frequenz
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Power-Saving Modi nutzen
sudo cpufreq-set -g powersave
```

---

## Problem: Datenbank ist korrupt

### Symptom
```
sqlite3.DatabaseError: database disk image is malformed
```

### Lösung

Die Datenbank komplett zurücksetzen:
```bash
# Alte Datenbank löschen
sudo rm /var/lib/rapiba/duplicate_db.sqlite3

# Service neustarten (erstellt Datenbank neu)
sudo systemctl restart rapiba

# Prüfe ob OK
sudo sqlite3 /var/lib/rapiba/duplicate_db.sqlite3 ".tables"
```

---

## Problem: udev Rules werden nicht geladen

### Symptom
Manual: `rapiba --list-devices` findet Geräte
Aber: Automatisches Triggering funktioniert nicht

### Lösungen

1. **Prüfe udev Rules installiert sind**
```bash
ls -la /etc/udev/rules.d/99-rapiba.rules
```

Falls nicht:
```bash
sudo cp udev/99-rapiba.rules /etc/udev/rules.d/
```

2. **Reload udev Rules**
```bash
sudo udevadm control --reload-rules
sudo udevadm control --reload
sudo udevadm trigger
```

3. **Test die Rules**
```bash
# Monitor starten
sudo udevadm monitor --property &

# Stecke USB-Stick ein und beobachte Output
```

---

## Debug-Modus aktivieren

### Maximum Verbosity

1. **Config auf Debug stellen**
```ini
LOG_LEVEL=DEBUG
DRY_RUN=yes  # Simulieren ohne zu kopieren
```

2. **Service neustarten**
```bash
sudo systemctl restart rapiba
```

3. **Logs beobachten**
```bash
journalctl -u rapiba -f
```

4. **Auch Konsolen-Output sehen**
```bash
sudo python3 /usr/local/lib/rapiba/backup_handler.py \
  --config /etc/rapiba/rapiba.conf \
  --backup-now /media/usb
```

---

## Häufig gestellte Fragen

### F: Wie oft sollte ich backups machen?
A: Abhängig von deinen Daten. Täglich ist gut, stündlich für kritische Daten.

### F: Kann ich mehrere USB-Sticks gleichzeitig anschließen?
A: Ja, das System erkennt alle und startet für jedes ein Backup.

### F: Sind meine Daten verschlüsselt?
A: Nein. Für verschlüsselte Backups nutze LUKS oder EncFS.

### F: Was wenn beim Backup Fehler auftreten?
A: Sie werden geloggt. Prüfe `/var/log/rapiba/`. Das Backup wird versucht zu vervollständigen.

### F: Kann ich das Backup während des Laufs unterbrechen?
A: Ja, aber schon kopierte Dateien werden nicht gelöscht. Der nächste Backup vervollständigt.

### F: Kann ich über SSH ferngesteuert Backups starten?
A: Ja: `ssh user@pi "sudo rapiba --backup-now"`

---

## Kontakt & Support

Bei weiteren Problemen:
1. Schau in `/var/log/rapiba/` nach detaillierten Logs
2. Prüf https://github.com/yourusername/rapiba/issues
3. Erstelle ein neues Issue mit Logs und Konfiguration
