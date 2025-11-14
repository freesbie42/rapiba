# Rapiba Service Error - Behebung

## Fehler: "Main process exited, code=exited, status=1/FAILURE"

Dieser Fehler bedeutet, dass der rapiba-Service beim Start kritisch fehlgeschlagen ist.

---

## 🔧 Schnelle Behebung (3 Schritte)

### Schritt 1: Führe Fix-Script aus
```bash
sudo bash fix_service.sh
```

Das Script:
- Erstellt fehlende Verzeichnisse
- Setzt Berechtigungen
- Überprüft Module
- Startet Service neu

### Schritt 2: Prüfe ob es funktioniert
```bash
systemctl status rapiba
journalctl -u rapiba -f
```

### Schritt 3: Test mit USB
Stecke USB-Stick an und beobachte Logs.

---

## 🔍 Debug-Schritte (falls Fix nicht hilft)

### 1. Debug-Script ausführen
```bash
sudo bash debug_service.sh
```

Das zeigt dir:
- Python-Version
- Modul-Verfügbarkeit
- Konfiguration
- Verzeichnisse
- Service-Logs

### 2. Manuell Service starten (für bessere Fehlerausgabe)
```bash
# Stop aktuellen Service
sudo systemctl stop rapiba

# Starte manuell mit Output
sudo python3 /usr/local/lib/rapiba/rapiba_monitor.py
```

### 3. Schau auf die Fehlerausgabe
```
Traceback (most recent call last):
  File "...", line X, in ...
```

Dieser Fehler zeigt das echte Problem.

---

## ❌ Häufige Fehler & Lösungen

### Fehler: "ModuleNotFoundError: No module named 'backup_handler'"
**Ursache**: Python-Module nicht installiert  
**Lösung**:
```bash
sudo cp src/*.py /usr/local/lib/rapiba/
sudo ls -la /usr/local/lib/rapiba/
```

### Fehler: "Configuration not found: /etc/rapiba/rapiba.conf"
**Ursache**: Konfiguration nicht installiert  
**Lösung**:
```bash
sudo mkdir -p /etc/rapiba
sudo cp etc/rapiba.conf /etc/rapiba/
sudo chmod 644 /etc/rapiba/rapiba.conf
```

### Fehler: "Permission denied" bei Verzeichnissen
**Ursache**: Berechtigungen falsch  
**Lösung**:
```bash
sudo chmod 755 /backup
sudo chmod 755 /var/lib/rapiba
sudo chmod 755 /var/log/rapiba
```

### Fehler: "RuntimeError: ... already has an entry"
**Ursache**: Monitor läuft bereits mehrfach  
**Lösung**:
```bash
sudo systemctl stop rapiba
sudo pkill -9 rapiba_monitor
sleep 2
sudo systemctl start rapiba
```

### Fehler: "sqlite3.OperationalError: database is locked"
**Ursache**: Duplikat-DB ist korrupt oder gesperrt  
**Lösung**:
```bash
sudo rm /var/lib/rapiba/duplicate_db.sqlite3
sudo systemctl restart rapiba
```

---

## 📊 Vollständige Diagnose-Checkliste

```bash
# 1. Prüfe Python
python3 --version

# 2. Prüfe Module
ls -la /usr/local/lib/rapiba/

# 3. Prüfe Config
ls -la /etc/rapiba/rapiba.conf
cat /etc/rapiba/rapiba.conf | head -20

# 4. Prüfe Verzeichnisse
ls -la /backup
ls -la /var/lib/rapiba
ls -la /var/log/rapiba

# 5. Prüfe Service
systemctl status rapiba
systemctl cat rapiba.service

# 6. Versuche manuell zu starten
sudo python3 /usr/local/lib/rapiba/rapiba_monitor.py

# 7. Schau Logs an
journalctl -u rapiba -n 50
tail -f /var/log/rapiba/*.log
```

---

## 🆘 Wenn alles fehlschlägt

### Option 1: Komplette Neuinstallation
```bash
# Deinstalliere alte Version
sudo systemctl stop rapiba
sudo rm -rf /usr/local/lib/rapiba
sudo rm -rf /etc/rapiba/rapiba.conf
sudo rm -f /usr/local/bin/rapiba*
sudo systemctl daemon-reload

# Installiere neu
cd rapiba
sudo bash install.sh
sudo bash fix_service.sh
```

### Option 2: Manuelles Setup (wenn install.sh fehlschlägt)
```bash
# 1. Erstelle Verzeichnisse
sudo mkdir -p /usr/local/lib/rapiba
sudo mkdir -p /etc/rapiba
sudo mkdir -p /var/lib/rapiba
sudo mkdir -p /var/log/rapiba
sudo mkdir -p /backup

# 2. Kopiere Python-Module
sudo cp src/*.py /usr/local/lib/rapiba/
sudo chmod 644 /usr/local/lib/rapiba/*.py

# 3. Kopiere Konfiguration
sudo cp etc/rapiba.conf /etc/rapiba/
sudo chmod 644 /etc/rapiba/rapiba.conf

# 4. Kopiere systemd-Dateien
sudo cp systemd/rapiba.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/rapiba.service

# 5. Erstelle Wrapper-Scripts
sudo bash -c 'cat > /usr/local/bin/rapiba << "EOF"
#!/bin/bash
exec /usr/bin/python3 /usr/local/lib/rapiba/backup_handler.py --config /etc/rapiba/rapiba.conf "$@"
EOF'

# 6. Berechtigungen
sudo chmod 755 /usr/local/bin/rapiba
sudo chmod 755 /usr/local/lib/rapiba
sudo chmod 755 /var/lib/rapiba
sudo chmod 755 /var/log/rapiba
sudo chmod 755 /backup

# 7. Service starten
sudo systemctl daemon-reload
sudo systemctl start rapiba
```

---

## ✅ Verifikation nach Behebung

```bash
# 1. Service läuft
systemctl is-active rapiba
# Sollte: active

# 2. Service läuft im Hintergrund
ps aux | grep rapiba_monitor | grep -v grep
# Sollte: Python-Prozess zeigen

# 3. Logs zeigen kein ERROR
journalctl -u rapiba | grep -i error
# Sollte: leer sein oder nur Warnungen

# 4. Verzeichnisse existieren
ls -la /backup /var/lib/rapiba /var/log/rapiba
# Alle sollten existieren
```

---

## 📞 Weitere Hilfe

Wenn du immer noch Probleme hast:

1. Führe aus: `sudo bash debug_service.sh`
2. Speichere Output in Datei: `sudo bash debug_service.sh > debug.txt 2>&1`
3. Überprüfe: `cat debug.txt`
4. Sieh TROUBLESHOOTING.md

---

## 🚀 Nächste Schritte nach Behebung

```bash
# 1. Überprüfe ob Service läuft
sudo systemctl status rapiba

# 2. Teste manuell
sudo rapiba --list-devices

# 3. Überwache Logs
journalctl -u rapiba -f

# 4. Stecke USB-Stick an
# → Sollte im Log automatisch erkannt werden

# 5. Starte Backup
rapiba --backup-now /media/usb
```

---

**Brauchst du weitere Hilfe? Führe `sudo bash debug_service.sh` aus und teile die Ausgabe!**
