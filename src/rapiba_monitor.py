#!/usr/bin/env python3
"""
Rapiba Monitor - Überwacht Geräte und startet Backups automatisch
"""

import os
import sys
import time
import logging
from datetime import datetime
from pathlib import Path

# Füge src-Verzeichnis zum Path hinzu
sys.path.insert(0, '/usr/local/lib/rapiba')

from backup_handler import Config, RapibaLogger, DeviceDetector, BackupEngine

def setup_logging():
    """Richte Logging für Monitor ein"""
    log_dir = '/var/log/rapiba'
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    logger = logging.getLogger('rapiba_monitor')
    logger.setLevel(logging.INFO)
    
    log_file = os.path.join(log_dir, f"monitor_{datetime.now().strftime('%Y-%m-%d')}.log")
    fh = logging.FileHandler(log_file)
    fh.setLevel(logging.INFO)
    
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    fh.setFormatter(formatter)
    logger.addHandler(fh)
    
    return logger


def main():
    logger = setup_logging()
    logger.info("Rapiba Monitor gestartet")
    
    config_path = '/etc/rapiba/rapiba.conf'
    if not os.path.exists(config_path):
        logger.error(f"Konfiguration nicht gefunden: {config_path}")
        sys.exit(1)
    
    try:
        config = Config(config_path)
        detector = DeviceDetector(config, logger)
        engine = BackupEngine(config, logger)
    except Exception as e:
        logger.error(f"Fehler beim Initialisieren: {e}", exc_info=True)
        sys.exit(1)
    
    known_devices = set()
    check_interval = 5  # Sekunden
    
    logger.info(f"Starte Device-Monitor mit {check_interval}s Intervall")
    logger.info(f"Überwache Quellen: {config.get('BACKUP_SOURCES')}")
    logger.info(f"Backup-Ziel: {config.get('BACKUP_TARGET')}")
    
    try:
        while True:
            try:
                # Erkenne neue Geräte
                current_devices = set(detector.detect_devices())
                new_devices = current_devices - known_devices
                
                if new_devices:
                    logger.info(f"Neue Geräte erkannt: {', '.join(new_devices)}")
                    
                    # Starte Backup für jedes neue Gerät
                    for device in new_devices:
                        logger.info(f"Starte Backup für {device}")
                        try:
                            device_name = os.path.basename(device) or 'backup'
                            engine.backup_source(device, device_name)
                        except Exception as e:
                            logger.error(f"Fehler beim Backup von {device}: {e}")
                
                # Prüfe auf entfernte Geräte
                removed_devices = known_devices - current_devices
                if removed_devices:
                    logger.info(f"Geräte entfernt: {', '.join(removed_devices)}")
                
                known_devices = current_devices
                time.sleep(check_interval)
            
            except Exception as e:
                logger.error(f"Fehler im Monitor-Loop: {e}", exc_info=True)
                time.sleep(check_interval)
    
    except KeyboardInterrupt:
        logger.info("Monitor beendet durch Benutzer")
    except Exception as e:
        logger.error(f"Kritischer Fehler: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
