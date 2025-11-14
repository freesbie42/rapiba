#!/usr/bin/env python3
"""
Rapiba - Raspberry Pi Automated Backup System
Automatisches Backup bei USB/SD-Card Anschluss mit Duplikat-Vermeidung
"""

import os
import sys
import json
import hashlib
import sqlite3
import logging
import configparser
import subprocess
import shutil
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse

# =====================================================
# KONFIGURATION UND SETUP
# =====================================================

class Config:
    """Lädt und verwaltet die Konfiguration aus rapiba.conf"""
    
    def __init__(self, config_path="/etc/rapiba/rapiba.conf"):
        self.config = configparser.ConfigParser()
        self.config_path = config_path
        self.config.read(config_path)
        
        # Defaults falls Config-Datei nicht vorhanden
        self.defaults = {
            'BACKUP_SOURCES': '/media/usb,/media/sdcard',
            'BACKUP_TARGET': '/backup',
            'BACKUP_PATH_FORMAT': 'both',
            'CUSTOM_PATH_FORMAT': '',
            'DUPLICATE_CHECK_METHOD': 'sha256',
            'DUPLICATE_DB_PATH': '/var/lib/rapiba/duplicate_db.sqlite3',
            'LOG_DIR': '/var/log/rapiba',
            'LOG_LEVEL': 'INFO',
            'AUTO_DETECT_DEVICES': 'yes',
            'AUTO_MOUNT_ATTEMPTS': '3',
            'AUTO_MOUNT_TIMEOUT': '10',
            'PARALLEL_JOBS': '2',
            'COMPRESS_BACKUPS': 'no',
            'COMPRESSION_LEVEL': '6',
            'VERIFY_CHECKSUMS': 'yes',
            'ENABLE_NOTIFICATIONS': 'no',
            'DELETE_OLD_BACKUPS_DAYS': '0',
            'MAX_BACKUPS_PER_SOURCE': '0',
            'BACKUP_DIR_MODE': '755',
            'BACKUP_FILE_MODE': '644',
            'BACKUP_OWNER': 'root:root',
            'DRY_RUN': 'no',
        }
    
    def get(self, key, default=None):
        """Gibt einen Config-Wert zurück"""
        if self.config.has_section('DEFAULT') and self.config.has_option('DEFAULT', key):
            return self.config.get('DEFAULT', key)
        if self.config.has_option('rapiba', key):
            return self.config.get('rapiba', key)
        return default or self.defaults.get(key, '')
    
    def get_bool(self, key):
        """Gibt einen Bool-Wert zurück"""
        value = self.get(key, 'no').lower()
        return value in ('yes', 'true', '1', 'on')
    
    def get_int(self, key, default=0):
        """Gibt einen Integer-Wert zurück"""
        try:
            return int(self.get(key, str(default)))
        except ValueError:
            return default


# =====================================================
# LOGGING
# =====================================================

class RapibaLogger:
    """Logger für Rapiba"""
    
    def __init__(self, config):
        self.config = config
        self.log_dir = config.get('LOG_DIR')
        self.log_level = config.get('LOG_LEVEL', 'INFO')
        
        # Erstelle Log-Verzeichnis
        Path(self.log_dir).mkdir(parents=True, exist_ok=True)
        
        self.logger = logging.getLogger('rapiba')
        level = getattr(logging, self.log_level.upper(), logging.INFO)
        self.logger.setLevel(level)
        
        # File Handler
        log_file = os.path.join(self.log_dir, f"rapiba_{datetime.now().strftime('%Y-%m-%d')}.log")
        fh = logging.FileHandler(log_file)
        fh.setLevel(level)
        
        # Console Handler
        ch = logging.StreamHandler()
        ch.setLevel(level)
        
        # Formatter
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        fh.setFormatter(formatter)
        ch.setFormatter(formatter)
        
        self.logger.addHandler(fh)
        self.logger.addHandler(ch)
    
    def get_logger(self):
        return self.logger


# =====================================================
# DUPLIKAT-DATENBANK
# =====================================================

class DuplicateDB:
    """SQLite Datenbank für Duplikat-Erkennung"""
    
    def __init__(self, db_path):
        self.db_path = db_path
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()
    
    def _init_db(self):
        """Initialisiert die Datenbank"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Tabelle für Datei-Hashes
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS file_hashes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_path TEXT NOT NULL,
                target_path TEXT NOT NULL,
                filename TEXT NOT NULL,
                filesize INTEGER,
                md5 TEXT,
                sha256 TEXT,
                modified_time REAL,
                copied_timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(source_path, filename)
            )
        ''')
        
        # Index für schnellere Abfragen
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_filename ON file_hashes(filename)
        ''')
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_sha256 ON file_hashes(sha256)
        ''')
        
        conn.commit()
        conn.close()
    
    def add_file(self, source_path, target_path, filename, filesize, md5=None, sha256=None, mod_time=None):
        """Fügt eine Datei zur Datenbank hinzu"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('''
                INSERT OR REPLACE INTO file_hashes 
                (source_path, target_path, filename, filesize, md5, sha256, modified_time)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (source_path, target_path, filename, filesize, md5, sha256, mod_time))
            conn.commit()
        except Exception as e:
            logger.error(f"Fehler beim Eintragen in Datenbank: {e}")
        finally:
            conn.close()
    
    def file_exists(self, filename, sha256=None, filesize=None):
        """Prüft ob eine Datei bereits kopiert wurde"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            if sha256:
                cursor.execute('SELECT * FROM file_hashes WHERE sha256 = ?', (sha256,))
            elif filesize:
                cursor.execute('SELECT * FROM file_hashes WHERE filename = ? AND filesize = ?', 
                             (filename, filesize))
            else:
                cursor.execute('SELECT * FROM file_hashes WHERE filename = ?', (filename,))
            
            result = cursor.fetchone()
            return result is not None
        finally:
            conn.close()
    
    def get_all_files(self):
        """Gibt alle gespeicherten Dateien zurück"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        try:
            cursor.execute('SELECT * FROM file_hashes')
            return cursor.fetchall()
        finally:
            conn.close()


# =====================================================
# HASH-FUNKTIONEN
# =====================================================

class FileHash:
    """Berechnet verschiedene Hashes für Dateien"""
    
    @staticmethod
    def md5(filepath):
        """Berechnet MD5-Hash"""
        hash_md5 = hashlib.md5()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    
    @staticmethod
    def sha256(filepath):
        """Berechnet SHA256-Hash"""
        hash_sha256 = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                hash_sha256.update(chunk)
        return hash_sha256.hexdigest()


# =====================================================
# BACKUP PATH GENERATOR
# =====================================================

class BackupPathGenerator:
    """Generiert Backup-Pfade basierend auf Config"""
    
    def __init__(self, config, backup_target):
        self.config = config
        self.backup_target = backup_target
        self.format_mode = config.get('BACKUP_PATH_FORMAT', 'both')
        self.custom_format = config.get('CUSTOM_PATH_FORMAT', '')
    
    def generate(self, source_name=None):
        """Generiert einen neuen Backup-Pfad"""
        now = datetime.now()
        
        if self.format_mode == 'datetime':
            dirname = now.strftime('%Y-%m-%d_%H-%M-%S')
        
        elif self.format_mode == 'number':
            dirname = f"backup_{self._get_next_number()}"
        
        elif self.format_mode == 'both':
            number = self._get_next_number()
            datetime_str = now.strftime('%Y-%m-%d_%H-%M-%S')
            dirname = f"backup_{number}_{datetime_str}"
        
        elif self.format_mode == 'custom' and self.custom_format:
            dirname = self._format_custom(now, source_name)
        
        else:
            dirname = now.strftime('%Y-%m-%d_%H-%M-%S')
        
        return os.path.join(self.backup_target, dirname)
    
    def _get_next_number(self):
        """Ermittelt die nächste Nummer"""
        try:
            existing = [d for d in os.listdir(self.backup_target) if os.path.isdir(os.path.join(self.backup_target, d))]
            numbers = []
            for d in existing:
                # Versuche Nummer zu extrahieren
                parts = d.split('_')
                if len(parts) > 1 and parts[1].isdigit():
                    numbers.append(int(parts[1]))
            return max(numbers) + 1 if numbers else 1
        except:
            return 1
    
    def _format_custom(self, now, source_name='backup'):
        """Formatiert Custom-Format"""
        fmt = self.custom_format
        fmt = fmt.replace('{datetime}', now.strftime('%Y-%m-%d_%H-%M-%S'))
        fmt = fmt.replace('{date}', now.strftime('%Y-%m-%d'))
        fmt = fmt.replace('{time}', now.strftime('%H-%M-%S'))
        fmt = fmt.replace('{number}', str(self._get_next_number()))
        fmt = fmt.replace('{source}', source_name or 'backup')
        return os.path.join(self.backup_target, fmt)


# =====================================================
# BACKUP ENGINE
# =====================================================

class BackupEngine:
    """Hauptengine für Backups"""
    
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.duplicate_db = DuplicateDB(config.get('DUPLICATE_DB_PATH'))
        self.check_method = config.get('DUPLICATE_CHECK_METHOD', 'sha256')
        self.dry_run = config.get_bool('DRY_RUN')
        self.parallel_jobs = config.get_int('PARALLEL_JOBS', 2)
    
    def backup_source(self, source_path, source_name=None):
        """Startet ein Backup einer Quelle"""
        if not os.path.exists(source_path):
            self.logger.warning(f"Quellpfad existiert nicht: {source_path}")
            return False
        
        if not os.path.isdir(source_path):
            self.logger.error(f"Quellpfad ist kein Verzeichnis: {source_path}")
            return False
        
        # Generiere Backup-Pfad
        gen = BackupPathGenerator(self.config, self.config.get('BACKUP_TARGET'))
        backup_path = gen.generate(source_name or os.path.basename(source_path))
        
        self.logger.info(f"Starte Backup von {source_path} nach {backup_path}")
        
        try:
            # Erstelle Backup-Verzeichnis
            if not self.dry_run:
                os.makedirs(backup_path, exist_ok=True)
                # Setze Berechtigungen
                mode = int(self.config.get('BACKUP_DIR_MODE', '755'), 8)
                os.chmod(backup_path, mode)
            
            # Kopiere Dateien
            return self._copy_directory(source_path, backup_path)
        
        except Exception as e:
            self.logger.error(f"Fehler beim Backup: {e}")
            return False
    
    def _copy_directory(self, source, target):
        """Kopiert ein Verzeichnis mit Duplikat-Erkennung"""
        total_files = 0
        copied_files = 0
        skipped_files = 0
        errors = 0
        
        # Sammle alle Dateien
        files_to_copy = []
        for root, dirs, files in os.walk(source):
            for file in files:
                src_file = os.path.join(root, file)
                rel_path = os.path.relpath(src_file, source)
                dst_file = os.path.join(target, rel_path)
                files_to_copy.append((src_file, dst_file, rel_path))
                total_files += 1
        
        self.logger.info(f"Insgesamt {total_files} Dateien zum Kopieren gefunden")
        
        # Kopiere mit Parallel-Jobs
        with ThreadPoolExecutor(max_workers=self.parallel_jobs) as executor:
            futures = {executor.submit(self._copy_file, src, dst, rel): (src, dst, rel) 
                      for src, dst, rel in files_to_copy}
            
            for future in as_completed(futures):
                src, dst, rel = futures[future]
                try:
                    result = future.result()
                    if result == 'copied':
                        copied_files += 1
                    elif result == 'skipped':
                        skipped_files += 1
                    elif result == 'error':
                        errors += 1
                except Exception as e:
                    self.logger.error(f"Fehler bei {src}: {e}")
                    errors += 1
        
        self.logger.info(f"Backup abgeschlossen: {copied_files} kopiert, {skipped_files} übersprungen, {errors} Fehler")
        return errors == 0
    
    def _copy_file(self, src_file, dst_file, rel_path):
        """Kopiert eine einzelne Datei mit Duplikat-Check"""
        try:
            # Berechne Hash
            file_hash = None
            file_size = os.path.getsize(src_file)
            mod_time = os.path.getmtime(src_file)
            
            if self.check_method == 'sha256':
                file_hash = FileHash.sha256(src_file)
            elif self.check_method == 'md5':
                file_hash = FileHash.md5(src_file)
            elif self.check_method == 'size_time':
                file_hash = f"{file_size}_{mod_time}"
            
            # Prüfe ob Datei bereits existiert
            if self.duplicate_db.file_exists(os.path.basename(src_file), file_hash, file_size):
                self.logger.debug(f"Datei übersprungen (Duplikat): {rel_path}")
                return 'skipped'
            
            # Kopiere Datei
            if not self.dry_run:
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                shutil.copy2(src_file, dst_file)
                
                # Setze Berechtigungen
                mode = int(self.config.get('BACKUP_FILE_MODE', '644'), 8)
                os.chmod(dst_file, mode)
            
            # Trage in Datenbank ein
            self.duplicate_db.add_file(
                src_file, dst_file, os.path.basename(src_file),
                file_size, 
                sha256=file_hash if self.check_method == 'sha256' else None,
                md5=file_hash if self.check_method == 'md5' else None,
                mod_time=mod_time
            )
            
            if self.dry_run:
                self.logger.debug(f"DRY-RUN: Würde kopieren {rel_path}")
            else:
                self.logger.debug(f"Datei kopiert: {rel_path}")
            
            return 'copied'
        
        except Exception as e:
            self.logger.error(f"Fehler beim Kopieren von {rel_path}: {e}")
            return 'error'


# =====================================================
# USB/SD-CARD ERKENNUNG
# =====================================================

class DeviceDetector:
    """Erkennt angeschlossene USB/SD-Card Geräte"""
    
    def __init__(self, config, logger):
        self.config = config
        self.logger = logger
        self.mount_points = ['/media', '/mnt', '/tmp/mnt']
    
    def detect_devices(self):
        """Erkennt angeschlossene Geräte"""
        devices = []
        
        for mount_point in self.mount_points:
            if os.path.exists(mount_point):
                try:
                    entries = os.listdir(mount_point)
                    for entry in entries:
                        full_path = os.path.join(mount_point, entry)
                        if os.path.isdir(full_path) and os.access(full_path, os.R_OK):
                            devices.append(full_path)
                            self.logger.info(f"Gerät erkannt: {full_path}")
                except Exception as e:
                    self.logger.debug(f"Fehler beim Durchsuchen von {mount_point}: {e}")
        
        return devices
    
    def find_new_devices(self, known_devices):
        """Findet neue Geräte seit letzter Überprüfung"""
        current = set(self.detect_devices())
        known = set(known_devices)
        new_devices = current - known
        return list(new_devices)


# =====================================================
# HAUPTPROGRAMM
# =====================================================

def main():
    global logger
    
    parser = argparse.ArgumentParser(description='Rapiba - Automated Raspberry Pi Backup')
    parser.add_argument('--config', '-c', default='/etc/rapiba/rapiba.conf', 
                       help='Pfad zur Konfigurationsdatei')
    parser.add_argument('--dry-run', action='store_true', 
                       help='Simuliert Backup ohne tatsächliches Kopieren')
    parser.add_argument('--backup-now', '-b', nargs='?', const='', 
                       help='Startet sofort ein Backup der angegebenen Quelle')
    parser.add_argument('--list-devices', '-l', action='store_true',
                       help='Listet erkannte Geräte auf')
    parser.add_argument('--list-backups', action='store_true',
                       help='Listet vorhandene Backups auf')
    
    args = parser.parse_args()
    
    # Lade Konfiguration
    config = Config(args.config)
    
    # Richte Logger ein
    rapiba_logger = RapibaLogger(config)
    logger = rapiba_logger.get_logger()
    
    if args.dry_run:
        config.config.set('DEFAULT', 'DRY_RUN', 'yes')
    
    logger.info("=" * 60)
    logger.info("Rapiba - Automated Raspberry Pi Backup")
    logger.info("=" * 60)
    
    try:
        # Listet Geräte auf
        if args.list_devices:
            detector = DeviceDetector(config, logger)
            devices = detector.detect_devices()
            if devices:
                logger.info(f"Erkannte Geräte: {', '.join(devices)}")
                for device in devices:
                    print(f"  - {device}")
            else:
                logger.info("Keine Geräte gefunden")
            return
        
        # Listet Backups auf
        if args.list_backups:
            backup_target = config.get('BACKUP_TARGET')
            if os.path.exists(backup_target):
                backups = sorted(os.listdir(backup_target))
                logger.info(f"Vorhandene Backups in {backup_target}:")
                for backup in backups:
                    backup_path = os.path.join(backup_target, backup)
                    if os.path.isdir(backup_path):
                        size = sum(os.path.getsize(os.path.join(dp, f)) 
                                 for dp, dn, filenames in os.walk(backup_path) 
                                 for f in filenames)
                        print(f"  - {backup} ({size / 1024 / 1024:.2f} MB)")
            else:
                logger.warning(f"Backup-Verzeichnis existiert nicht: {backup_target}")
            return
        
        # Startet Backup
        engine = BackupEngine(config, logger)
        
        if args.backup_now is not None:
            # Manually trigger backup
            if args.backup_now:
                sources = [args.backup_now]
            else:
                sources = [s.strip() for s in config.get('BACKUP_SOURCES').split(',')]
            
            for source in sources:
                if os.path.exists(source):
                    engine.backup_source(source)
        else:
            logger.info("Kein Backup-Modus angegeben. Verwende --help für Optionen.")
    
    except Exception as e:
        logger.error(f"Kritischer Fehler: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
