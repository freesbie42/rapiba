#!/usr/bin/env python3
"""
Rapiba Trigger - Wird von udev aufgerufen wenn USB/SD-Card angesteckt wird
"""

import os
import sys
import logging
from pathlib import Path

# Füge src-Verzeichnis zum Path hinzu
sys.path.insert(0, '/usr/local/lib/rapiba')

from backup_handler import Config, DeviceDetector, BackupEngine


def main():
    """Wird vom udev-Rule aufgerufen"""
    
    log_dir = '/var/log/rapiba'
    Path(log_dir).mkdir(parents=True, exist_ok=True)
    
    # Setup Logging
    logger = logging.getLogger('rapiba_trigger')
    logger.setLevel(logging.DEBUG)
    
    handler = logging.FileHandler(os.path.join(log_dir, 'trigger.log'))
    handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
    logger.addHandler(handler)
    
    try:
        logger.info(f"Trigger aufgerufen mit DEVNAME={os.environ.get('DEVNAME', 'N/A')}")
        
        config_path = '/etc/rapiba/rapiba.conf'
        if not os.path.exists(config_path):
            logger.error(f"Konfiguration nicht gefunden: {config_path}")
            return
        
        config = Config(config_path)
        
        # Erkenne aktuelle Geräte (ohne Backup-Ziel)
        detector = DeviceDetector(config, logger)
        devices = detector.detect_devices(exclude_backup_target=True)
        
        if devices:
            logger.info(f"🔌 {len(devices)} Gerät(e) erkannt - starte Backup: {', '.join(devices)}")
            engine = BackupEngine(config, logger)
            
            for device in devices:
                try:
                    device_name = os.path.basename(device) or 'backup'
                    logger.info(f"→ Backup von {device} läuft...")
                    success = engine.backup_source(device, device_name)
                    if success:
                        logger.info(f"✅ Backup erfolgreich für {device}")
                    else:
                        logger.warning(f"⚠️ Backup mit Fehlern abgeschlossen für {device}")
                except Exception as e:
                    logger.error(f"❌ Fehler beim Backup von {device}: {e}")
        else:
            logger.info("ℹ️ Keine neuen Speichergeräte erkannt")
    
    except Exception as e:
        logger.error(f"❌ Fehler im Trigger: {e}", exc_info=True)


if __name__ == '__main__':
    main()
