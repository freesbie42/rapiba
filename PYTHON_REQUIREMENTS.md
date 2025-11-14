# Rapiba - Python3 Requirements

## Anforderungen

### Minimum Python Version
- **Python 3.6 oder höher** erforderlich
- Python 2 wird **NICHT** unterstützt

### Erforderliche Standard Library Module

Alle diese Module sind in Python 3.6+ standardmäßig enthalten:

```
✓ sys              - System-Funktionen
✓ os               - Betriebssystem-Interface
✓ time             - Zeit-Funktionen
✓ logging          - Logging
✓ configparser     - Config-Dateien parsing
✓ subprocess       - Externe Prozesse
✓ shutil           - High-level Datei-Operationen
✓ pathlib          - Pfad-Operationen
✓ datetime         - Datums- und Zeitfunktionen
✓ hashlib          - Kryptographische Hashes (MD5, SHA256)
✓ sqlite3          - SQLite Datenbank
✓ json             - JSON encoding/decoding
✓ argparse         - Command-line Parser
✓ concurrent.futures - Parallele Ausführung
✓ threading        - Threading-Operationen
```

### Optional Module

Diese Module verbessern die Funktionalität:

```
⚡ tabulate        - Schönere Tabellenformatierung (optional)
   Installieren: pip3 install tabulate
```

---

## Installation

### Raspberry Pi OS / Debian / Ubuntu

```bash
# Update Package List
sudo apt-get update

# Installiere Python3 mit wichtigen Komponenten
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-dev

# Optional: Installiere tabulate für schönere Ausgabe
sudo pip3 install tabulate
```

### macOS

```bash
# Mit Homebrew
brew install python3

# Oder mit MacPorts
sudo port install python310

# Optional: tabulate
pip3 install tabulate
```

### Andere Linux-Distributionen

```bash
# Fedora / RHEL / CentOS
sudo dnf install python3 python3-pip

# Arch Linux
sudo pacman -S python python-pip

# OpenSUSE
sudo zypper install python3 python3-pip
```

---

## Verfügbarkeit überprüfen

### Schnelle Überprüfung
```bash
# Check ob Python3 vorhanden ist
python3 --version

# Check ob erforderliche Module vorhanden sind
python3 -c "import sqlite3, hashlib, json; print('OK')"
```

### Umfangreiche Überprüfung
```bash
# Verwende das Check-Script
bash check_python_requirements.sh
```

### Nach Installation
```bash
# Rapiba wird Python-Anforderungen überprüfen
sudo bash install.sh
# Der Installer stoppt, wenn Python-Anforderungen nicht erfüllt sind
```

---

## Raspberry Pi - Spezifische Anleitung

### Raspberry Pi OS (Standard)

Python3 sollte bereits vorinstalliert sein:

```bash
# Überprüfe
python3 --version

# Falls nicht vorhanden:
sudo apt-get update
sudo apt-get install -y python3 python3-pip
```

### Raspberry Pi Zero / Zero W

Falls Speicherplatz begrenzt ist:

```bash
# Minimale Installation
sudo apt-get install -y python3

# Nicht installieren (optional):
# - python3-pip (falls nicht nötig)
# - tabulate (falls nicht nötig)
```

### Version-Kompatibilität nach Raspberry Pi Modell

| Modell | OS | Python3 | Status |
|--------|-------|---------|--------|
| Zero / Zero W | Raspbian Lite | 3.9+ | ✓ Funktioniert |
| Pi 3 / 3B+ | Raspbian | 3.9+ | ✓ Optimal |
| Pi 4 | Raspberry Pi OS | 3.10+ | ✓ Optimal |
| Pi 5 | Raspberry Pi OS | 3.11+ | ✓ Optimal |

---

## Anforderungs-Check vor Installation

### Automatisch (empfohlen)
```bash
# Vor Installation
bash check_python_requirements.sh

# Vor der Installation wird auch im install.sh überprüft
sudo bash install.sh
```

### Manuell
```bash
# Python3 vorhanden?
command -v python3

# Minimum Version 3.6?
python3 -c "import sys; assert sys.version_info >= (3, 6)"

# SQLite3 vorhanden?
python3 -c "import sqlite3"

# Hashlib vorhanden?
python3 -c "import hashlib"
```

---

## Fehler-Behebung

### "python3: command not found"

```bash
# Installation erforderlich
sudo apt-get update
sudo apt-get install -y python3

# Überprüfung
python3 --version
```

### "ModuleNotFoundError: No module named 'sqlite3'"

Dies sollte nicht vorkommen, da sqlite3 Standard ist. Wenn doch:

```bash
# Neuinstallation von Python3
sudo apt-get remove python3
sudo apt-get install -y python3
```

### "version_info too old: 3.5 (minimum 3.6)"

Python Version ist zu alt. Upgrade erforderlich:

```bash
# Überprüfe aktuelle Version
python3 --version

# Falls < 3.6:
# - Upgrade OS (z.B. neuere Raspbian Version)
# - Oder baue Python3.10+ aus source
```

---

## Environment Variables (Optional)

Falls mehrere Python-Versionen installiert sind:

```bash
# Setze bevorzugte Python Version
export PYTHONPATH="/usr/local/lib/rapiba:$PYTHONPATH"

# Verwende explizit Python3
/usr/bin/python3 --version
```

---

## Virtual Environments (Optional, nicht empfohlen für Rapiba)

Rapiba funktioniert am besten als System-Service, daher Virtual Environments nicht nötig.

Falls trotzdem gewünscht:

```bash
# Erstelle Virtual Environment
python3 -m venv /opt/rapiba-venv

# Aktiviere
source /opt/rapiba-venv/bin/activate

# Installiere Requirements
pip install -r requirements.txt
```

---

## Performance-Hinweise

### Python3 Versionen

| Version | Release | Performance | Empfehlung |
|---------|---------|-------------|------------|
| 3.6 | 2016 | Baseline | Minimum |
| 3.7 | 2018 | +5% | Gut |
| 3.8 | 2019 | +8% | Besser |
| 3.9 | 2020 | +10% | Empfohlen |
| 3.10+ | 2021+ | +15% | Optimal |

Neuere Versionen = bessere Performance und Sicherheit.

---

## Troubleshooting

### Service startet nicht

```bash
# 1. Check Python
python3 --version

# 2. Run Debug Script
sudo bash debug_service.sh

# 3. Manual start mit Output
sudo python3 /usr/local/lib/rapiba/rapiba_monitor.py
```

### Import Fehler

```bash
# Überprüfe PATH
echo $PATH
python3 -c "import sys; print(sys.path)"

# Setze PATH wenn nötig
export PYTHONPATH="/usr/local/lib/rapiba:$PYTHONPATH"
```

---

## Weitere Ressourcen

- [Python3 Dokumentation](https://docs.python.org/3/)
- [Raspberry Pi Python](https://www.raspberrypi.com/documentation/computers/os.html)
- [Debian Python](https://wiki.debian.org/Python)

---

**Version**: 1.0.0  
**Stand**: November 2025  
**Status**: ✓ Production-Ready
