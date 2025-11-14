# Rapiba - Performance & Optimization Guide

## Performance-Tipps

### 1. Parallel-Jobs anpassen

```ini
# Für Single-Core oder langsame SD-Cards
PARALLEL_JOBS=1

# Für Dual-Core
PARALLEL_JOBS=2

# Für Quad-Core oder besser
PARALLEL_JOBS=4
```

**Auswirkung**: Mehr Jobs = schneller, aber höhere CPU-Last und I/O-Contention

### 2. Richtige Duplikat-Erkennungsmethode

```ini
# Sicherest (aber langsam)
DUPLICATE_CHECK_METHOD=sha256
# → Ideal für wichtige Daten, kleine Geräte

# Schneller
DUPLICATE_CHECK_METHOD=md5
# → Guter Kompromiss

# Schnellst (aber fehleranfällig)
DUPLICATE_CHECK_METHOD=size_time
# → Nur für schnelle vorläufige Backups

# Keine Duplikat-Erkennung (schnellst)
DUPLICATE_CHECK_METHOD=none
# → Nur wenn Duplikate egal sind
```

### 3. Checksummen-Verifikation

```ini
# Verifikation nach Backup
VERIFY_CHECKSUMS=yes
# → Langsamer, aber sicherer

# Keine Verifikation
VERIFY_CHECKSUMS=no
# → Schneller, aber weniger sicher
```

### 4. Logging-Level

```ini
# Debug (sehr detailliert, langsamer)
LOG_LEVEL=DEBUG

# Info (Standard)
LOG_LEVEL=INFO

# Warning (nur Warnungen und Fehler)
LOG_LEVEL=WARNING

# Error (nur Fehler)
LOG_LEVEL=ERROR
```

## Benchmarks (ungefähre Werte)

Auf Raspberry Pi 4 (4GB RAM) mit 2000 Dateien (ca. 5GB):

| Szenario | Zeit | CPU | I/O |
|----------|------|-----|-----|
| 1x SHA256 | 12m | 25% | High |
| 2x SHA256 | 8m | 50% | High |
| 4x SHA256 | 6m | 95% | Very High |
| 2x MD5 | 5m | 40% | High |
| 2x size_time | 2m | 15% | Medium |
| 2x none | 1m30s | 10% | Low |

## Optimiert für verschiedene Hardware

### Raspberry Pi Zero / Zero W (Single-Core)
```ini
PARALLEL_JOBS=1
DUPLICATE_CHECK_METHOD=size_time
VERIFY_CHECKSUMS=no
LOG_LEVEL=WARNING
```

### Raspberry Pi 3 / 3B+ (Quad-Core)
```ini
PARALLEL_JOBS=2
DUPLICATE_CHECK_METHOD=md5
VERIFY_CHECKSUMS=no
LOG_LEVEL=INFO
```

### Raspberry Pi 4 (Quad-Core, 4GB+)
```ini
PARALLEL_JOBS=4
DUPLICATE_CHECK_METHOD=sha256
VERIFY_CHECKSUMS=yes
LOG_LEVEL=INFO
```

## Speicher-Optimierung

### Große Dateien (> 1GB)

```ini
# Streaming-Modus für große Dateien
# (wird automatisch für sehr große Dateien genutzt)
PARALLEL_JOBS=1
DUPLICATE_CHECK_METHOD=size_time
```

### Viele kleine Dateien (> 10.000)

```ini
# Höhere Parallelität hilft
PARALLEL_JOBS=4
DUPLICATE_CHECK_METHOD=md5
```

## Disk-I/O Optimierung

### Schnelle USB 3.0 / SSD
```ini
PARALLEL_JOBS=4
DUPLICATE_CHECK_METHOD=sha256
```

### Langsame USB 2.0 / SD-Card
```ini
PARALLEL_JOBS=1
DUPLICATE_CHECK_METHOD=size_time
```

### Netzwerk-Backup (NFS/SMB)
```ini
PARALLEL_JOBS=2
DUPLICATE_CHECK_METHOD=md5
```

## Speicherplatz sparen

```ini
# Alte Backups automatisch löschen
DELETE_OLD_BACKUPS_DAYS=30

# Maximale Anzahl halten
MAX_BACKUPS_PER_SOURCE=5

# Kompression (reduziert Größe, erhöht CPU)
COMPRESS_BACKUPS=yes
COMPRESSION_LEVEL=6
```

## RAM-Bedarf

- Ohne Duplikat-Datenbank: ~50MB
- Mit Duplikat-Datenbank (10.000 Dateien): ~80MB
- Mit Duplikat-Datenbank (100.000 Dateien): ~150MB

Für Raspberry Pi Zero: `PARALLEL_JOBS=1` empfohlen

## Profiling

Zum Messen der Performance:

```bash
# Dry-Run mit Zeit-Messung
time rapiba --dry-run --backup-now /media/usb

# CPU- und Memory-Nutzung
top -p $(pgrep -f rapiba_monitor)

# Disk I/O
iostat -x 1

# Network (bei NFS/SMB)
nethogs
```

## Tipps für Raspberry Pi

1. **Übertakten vermeiden**: Thermal Throttling kann Performance zerstören
2. **Gutes Netzteil**: Unter 2.5A für Pi 4 macht Performance-Probleme
3. **SD-Card Klasse**: Mindestens Class 10 (U3) für akzeptable Performance
4. **USB-Verteiler**: Einen powered USB Hub verwenden, nicht zu viele Geräte gleichzeitig
5. **Zeitplan**: Backups nachts laufen lassen, wenn System weniger last hat

## Monitoring

```bash
# Live-Monitoring der Backup-Performance
watch -n 1 'du -sh /backup/*'

# Datenbank-Größe
du -sh /var/lib/rapiba/duplicate_db.sqlite3

# Log-Größe
du -sh /var/log/rapiba/

# Speicher-Auslastung
free -h

# Disk-Auslastung
df -h
```
