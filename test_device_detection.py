#!/usr/bin/env python3
"""
Test-Script für die neue DeviceDetector-Funktionalität

Prüft:
1. Alle Geräte erkennen
2. Backup-Ziel ausschließen
3. Systemdateisysteme filtern
4. Neue/Entfernte Geräte erkennen
"""

import sys
import os
from pathlib import Path

# Füge src zum Path hinzu
sys.path.insert(0, '/Users/ma/Development/rapiba2/src')

from backup_handler import Config, DeviceDetector, RapibaLogger

def print_section(title):
    print("\n" + "=" * 60)
    print(f"  {title}")
    print("=" * 60)

def test_device_detection():
    """Test der Device-Erkennung"""
    print_section("🧪 DeviceDetector Test")
    
    # Config laden
    config_path = '/Users/ma/Development/rapiba2/etc/rapiba.conf'
    if not os.path.exists(config_path):
        print("❌ Konfigurationsdatei nicht gefunden:", config_path)
        return False
    
    try:
        config = Config(config_path)
        logger = RapibaLogger(config).get_logger()
        
        print("✅ Config und Logger initialisiert")
        print(f"   BACKUP_TARGET: {config.get('BACKUP_TARGET')}")
        
        # Erstelle Detector
        detector = DeviceDetector(config, logger)
        print("✅ DeviceDetector instanziiert")
        
        # Test 1: Alle Geräte erkennen
        print_section("Test 1: Alle Geräte erkennen")
        devices = detector.detect_devices(exclude_backup_target=True)
        print(f"✅ {len(devices)} Geräte erkannt")
        for device in devices:
            print(f"   → {device}")
        
        # Test 2: Filterung prüfen
        print_section("Test 2: Dateisystem-Filterung")
        print(f"Ausgeschlossene Dateisysteme:")
        for fs in sorted(detector.SYSTEM_FILESYSTEMS):
            print(f"   - {fs}")
        
        # Test 3: Backup-Ziel
        print_section("Test 3: Backup-Ziel-Erkennung")
        backup_target = detector.backup_target
        print(f"Backup-Ziel (real path): {backup_target}")
        
        # Prüfe ob in devices
        if backup_target in devices:
            print("⚠️ WARNUNG: Backup-Ziel ist in Devices enthalten (Filterung fehlgeschlagen)")
            return False
        else:
            print("✅ Backup-Ziel wurde korrekt ausgeschlossen")
        
        # Test 4: Neue Geräte
        print_section("Test 4: Neue Geräte erkennen")
        known = devices[:1] if devices else []
        new = detector.find_new_devices(known, exclude_backup_target=True)
        print(f"Bekannte Geräte: {known}")
        print(f"Neue Geräte: {new}")
        if new:
            print(f"✅ {len(new)} neue Geräte erkannt")
        else:
            print("ℹ️ Keine neuen Geräte (alle bekannt)")
        
        # Test 5: Entfernte Geräte
        print_section("Test 5: Entfernte Geräte erkennen")
        if len(devices) > 1:
            hypothetical_known = devices
            removed = detector.find_removed_devices(hypothetical_known)
            print(f"Hypothetisch bekannte: {hypothetical_known}")
            print(f"Entfernte Geräte: {removed}")
        else:
            print("ℹ️ Nicht genug Geräte für Test (mindestens 2 nötig)")
        
        # Test 6: Escape-Zeichen
        print_section("Test 6: Mount-Daten lesen")
        mount_data = detector._read_mounts()
        print(f"✅ {len(mount_data)} Mount-Einträge gelesen")
        if mount_data:
            print("\nBeispiel-Mounts:")
            for device, mount_point, fs in mount_data[:5]:
                print(f"   {device:20} → {mount_point:30} ({fs})")
        
        # Test 7: Dateisystem-Validierung
        print_section("Test 7: Dateisystem-Validierung")
        test_cases = [
            ('ext4', True, 'Linux Native'),
            ('vfat', True, 'USB/SD-Karten'),
            ('ntfs', True, 'Windows'),
            ('tmpfs', False, 'RAM-Dateisystem'),
            ('sysfs', False, 'Kernel-Interface'),
            ('proc', False, '/proc Filesystem'),
        ]
        
        for fs, expected, description in test_cases:
            result = detector._is_valid_filesystem(fs)
            status = "✅" if result == expected else "❌"
            print(f"{status} {fs:15} → {result:5} (erwartet: {expected:5}) - {description}")
        
        # Test 8: System-Pfade
        print_section("Test 8: System-Pfad-Erkennung")
        test_paths = [
            ('/', True, 'Root'),
            ('/sys', True, 'Sysfs'),
            ('/boot', True, 'Boot-Partition'),
            ('/media/usb', False, 'USB-Mount'),
            ('/mnt/external', False, 'External Drive'),
            ('/var/tmp', True, 'System-Temp'),
        ]
        
        for path, expected, description in test_paths:
            result = detector._is_system_mount(path)
            status = "✅" if result == expected else "❌"
            print(f"{status} {path:20} → System: {result:5} - {description}")
        
        print_section("✅ Alle Tests abgeschlossen!")
        return True
    
    except Exception as e:
        print(f"❌ Fehler: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == '__main__':
    success = test_device_detection()
    sys.exit(0 if success else 1)
