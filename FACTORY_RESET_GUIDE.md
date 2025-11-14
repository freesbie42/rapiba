# Factory Reset Guide - Werkseinstellung zurücksetzen

## Übersicht

Der `factory-reset` Befehl setzt Rapiba auf Werkseinstellungen zurück und löscht alle gespeicherten Daten.

## Verwendung

```bash
sudo rapiba --factory-reset
```

## Was wird gelöscht?

| Element | Pfad | Beschreibung |
|---------|------|-------------|
| Duplikat-DB | `/var/lib/rapiba/` | SQLite-Datenbank mit kopierten Dateien |
| Log-Dateien | `/var/log/rapiba/` | Alle Backup- und Monitor-Logs |
| Backups | `/backup/` | Alle erstellten Backups |
| Konfiguration | `/etc/rapiba/` | Benutzer-Konfiguration (wird zurückgesetzt) |

## Was wird NICHT gelöscht?

- Konfigurationsdatei wird wiederhergestellt (mit Werkseinstellungen)
- Systemd-Service-Dateien bleiben installiert
- udev-Regeln bleiben installiert
- Binärdateien in `/usr/local/bin/` und `/usr/local/lib/` bleiben

## Sicherheitsmechanismen

Das System hat zwei Bestätigungsebenen:

### 1. Bestätigung 1: Texteinput
```
Wirklich alle Daten löschen? Gib 'FACTORY RESET' ein zum Bestätigen:
```
Du musst genau `FACTORY RESET` (Großbuchstaben) eingeben.

### 2. Bestätigung 2: Letzte Warnung
```
LETZTE WARNUNG: Dies kann nicht rückgängig gemacht werden. Ja/Nein:
```
Du musst `Ja` eingeben zur abschließenden Bestätigung.

## Ablauf

1. ✓ Service stoppen (`rapiba`, `rapiba-backup.timer`, `rapiba-backup.service`)
2. ✓ Duplikat-Datenbank löschen und neu erstellen
3. ✓ Log-Verzeichnis löschen und neu erstellen
4. ✓ Backup-Verzeichnis löschen und neu erstellen
5. ✓ Konfigurationsverzeichnis löschen und neu erstellen
6. ✓ Standard-Konfiguration wiederherstellen
7. ✓ Service neu starten

## Beispiel-Szenario

```bash
$ sudo rapiba --factory-reset

════════════════════════════════════════
  ⚠️  WERKSEINSTELLUNG ZURÜCKSETZEN
════════════════════════════════════════

WARNUNG: Dies werden alle gespeicherten Daten löschen:
  • Duplikat-Datenbank
  • Alle Log-Dateien
  • Backup-Verzeichnisse werden gelöscht
  • Konfiguration wird zurückgesetzt

Die folgenden Verzeichnisse werden GELÖSCHT:
  • /var/lib/rapiba/ (Duplikat-DB)
  • /var/log/rapiba/ (Logs)
  • /backup/ (Alle Backups)
  • /etc/rapiba/ (Konfiguration)

Wirklich alle Daten löschen? Gib 'FACTORY RESET' ein zum Bestätigen: FACTORY RESET

LETZTE WARNUNG: Dies kann nicht rückgängig gemacht werden. Ja/Nein: Ja

ℹ Starte Werkseinstellung-Reset...
ℹ Stoppe Services...
ℹ Lösche Duplikat-Datenbank...
ℹ Lösche Log-Dateien...
ℹ Lösche Backup-Verzeichnis...
ℹ Lösche Konfiguration...
ℹ Stelle Standard-Konfiguration wieder her...
✓ Standard-Konfiguration wiederhergestellt
ℹ Starte Service neu...

✓ Werkseinstellung erfolgreich zurückgesetzt!

Nächste Schritte:
  1. Konfiguriere: sudo nano /etc/rapiba/rapiba.conf
  2. Oder nutze Quick-Setup: sudo rapiba --quick-setup
  3. Prüfe Status: rapiba --status
```

## Wann sollte man Factory Reset verwenden?

### ✓ Good Use Cases

- 🔧 Nach Upgrades wenn Konfiguration korrupt ist
- 🗑️ Wenn die Duplikat-Datenbank korrupt wurde
- 🔄 Kompletter Neustart des Systems gewünscht
- 🧹 Cleanup nach Tests/Experimenten
- 🚀 Vollständiger Reset vor Wiederverkauf des Geräts

### ✗ NOT empfohlen für

- 🛑 Wenn du deine Backups behalten möchtest (verwende stattdessen `sudo systemctl restart rapiba`)
- 📋 Wenn du nur Logs löschen möchtest (`sudo rm -rf /var/log/rapiba/`)
- 🔍 Wenn du nur die Duplikat-DB zurücksetzen möchtest (`sudo rm /var/lib/rapiba/duplicate_db.sqlite3`)

## Alternativen

Je nachdem was du nur bereinigen möchtest:

### Nur Logs löschen
```bash
sudo rm -rf /var/log/rapiba
sudo mkdir -p /var/log/rapiba
sudo systemctl restart rapiba
```

### Nur Duplikat-Datenbank zurücksetzen
```bash
sudo rm /var/lib/rapiba/duplicate_db.sqlite3
sudo systemctl restart rapiba
```

### Nur Backups löschen (Konfiguration behalten)
```bash
sudo rm -rf /backup/*
```

### Konfiguration zurücksetzen (Backups behalten)
```bash
sudo rm /etc/rapiba/rapiba.conf
sudo cp rapiba/etc/rapiba.conf /etc/rapiba/rapiba.conf
sudo systemctl restart rapiba
```

## Häufig gestellte Fragen (FAQ)

### F: Kann ich den Factory Reset abbrechen?
A: Ja, während der Bestätigungsprompts kannst du abbrechen durch:
- Falsche Eingabe bei Bestätigung 1
- `nein` statt `Ja` bei Bestätigung 2

### F: Was passiert mit meinen Backups?
A: **Alle Backups im `/backup/` Verzeichnis werden gelöscht!**
Sichere deine Backups vorher extern, falls du sie behalten möchtest.

### F: Wie lange dauert Factory Reset?
A: Normalerweise < 5 Sekunden (schnelles Löschen)
Bei großen Backup-Verzeichnissen kann es länger dauern.

### F: Kann ich Factory Reset ohne root machen?
A: Nein, du brauchst `sudo` da das System systemd und Systemverzeichnisse beeinflusst.

### F: Was ist nach Factory Reset installiert?
A: Das System ist in genau diesem Zustand wie nach `sudo rapiba install`:
- Alle Binärdateien installiert
- Alle Service-Dateien installiert
- Aber alle Daten gelöscht
- Neue, leere Standard-Konfiguration

### F: Kann ich Factory Reset rückgängig machen?
A: **NEIN!** Dies ist permanent und kann nicht rückgängig gemacht werden.
Stelle deine Backups aus externen Sicherungen wieder her, falls nötig.

## Recovery nach Factory Reset

Falls du Daten wiederherstellen möchtest:

### Von externen Backups
```bash
# Falls du externe Backups hast, kopiere sie zurück:
cp /external_backup/* /backup/

# Aktualisiere dann die Duplikat-DB
sudo systemctl restart rapiba
```

### Nur Konfiguration
```bash
# Falls du nur die Konfiguration brauchst
nano /etc/rapiba/rapiba.conf
# (Konfiguriere manuell oder nutze quicksetup)
```

## Tipps & Tricks

### Automatisierter Factory Reset (mit Vorsicht!)
```bash
# WARNUNG: Dies löscht ohne weitere Bestätigung!
echo -e "FACTORY RESET\nJa" | sudo rapiba --factory-reset
```

### Logging vor Factory Reset
```bash
# Sichere Logs bevor du Reset machst
sudo cp -r /var/log/rapiba /home/pi/rapiba_logs_backup

# Dann Factory Reset
sudo rapiba --factory-reset
```

### Backup der Konfiguration
```bash
# Vor Factory Reset: Speichere aktuelle Konfiguration
sudo cp /etc/rapiba/rapiba.conf ~/my_rapiba_config.conf

# Nach Factory Reset: Stelle sie wieder her
sudo cp ~/my_rapiba_config.conf /etc/rapiba/rapiba.conf
sudo systemctl restart rapiba
```

---

**Hinweis**: Factory Reset ist ein mächtiges Werkzeug. Verwende es mit Bedacht!
