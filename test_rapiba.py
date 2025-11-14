#!/usr/bin/env python3
"""
Rapiba Unit Tests
"""

import unittest
import tempfile
import os
import sys
from datetime import datetime

sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import (
    Config, FileHash, BackupPathGenerator, 
    DuplicateDB, DeviceDetector
)


class TestConfig(unittest.TestCase):
    """Tests für Config-Klasse"""
    
    def setUp(self):
        self.temp_config = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.conf')
        self.config_path = self.temp_config.name
        self.temp_config.write("[DEFAULT]\n")
        self.temp_config.write("BACKUP_TARGET=/test/backup\n")
        self.temp_config.write("PARALLEL_JOBS=4\n")
        self.temp_config.close()
    
    def tearDown(self):
        os.unlink(self.config_path)
    
    def test_load_config(self):
        config = Config(self.config_path)
        self.assertEqual(config.get('BACKUP_TARGET'), '/test/backup')
    
    def test_get_int(self):
        config = Config(self.config_path)
        self.assertEqual(config.get_int('PARALLEL_JOBS'), 4)
    
    def test_get_bool(self):
        config = Config(self.config_path)
        config.config.set('DEFAULT', 'DRY_RUN', 'yes')
        self.assertTrue(config.get_bool('DRY_RUN'))


class TestFileHash(unittest.TestCase):
    """Tests für Hash-Funktionen"""
    
    def setUp(self):
        self.temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False)
        self.temp_file.write("test content")
        self.temp_file.close()
        self.file_path = self.temp_file.name
    
    def tearDown(self):
        os.unlink(self.file_path)
    
    def test_md5(self):
        hash_value = FileHash.md5(self.file_path)
        self.assertEqual(len(hash_value), 32)  # MD5 ist 32 Hex-Zeichen
    
    def test_sha256(self):
        hash_value = FileHash.sha256(self.file_path)
        self.assertEqual(len(hash_value), 64)  # SHA256 ist 64 Hex-Zeichen


class TestBackupPathGenerator(unittest.TestCase):
    """Tests für Backup-Pfad-Generierung"""
    
    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.temp_config = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.conf')
        self.config_path = self.temp_config.name
        self.temp_config.write("[DEFAULT]\n")
        self.temp_config.write(f"BACKUP_TARGET={self.temp_dir}\n")
        self.temp_config.write("BACKUP_PATH_FORMAT=datetime\n")
        self.temp_config.close()
    
    def tearDown(self):
        import shutil
        os.unlink(self.config_path)
        shutil.rmtree(self.temp_dir)
    
    def test_datetime_format(self):
        config = Config(self.config_path)
        gen = BackupPathGenerator(config, config.get('BACKUP_TARGET'))
        path = gen.generate()
        self.assertIn(self.temp_dir, path)
        # Prüfe ob Format YYYY-MM-DD_HH-MM-SS
        basename = os.path.basename(path)
        self.assertRegex(basename, r'\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}')


class TestDuplicateDB(unittest.TestCase):
    """Tests für Duplikat-Datenbank"""
    
    def setUp(self):
        self.temp_db = tempfile.NamedTemporaryFile(delete=False, suffix='.db')
        self.db_path = self.temp_db.name
        self.temp_db.close()
        self.db = DuplicateDB(self.db_path)
    
    def tearDown(self):
        if os.path.exists(self.db_path):
            os.unlink(self.db_path)
    
    def test_add_and_check_file(self):
        self.db.add_file(
            source_path='/media/usb/test.txt',
            target_path='/backup/test.txt',
            filename='test.txt',
            filesize=1024,
            sha256='abc123'
        )
        
        exists = self.db.file_exists('test.txt', sha256='abc123')
        self.assertTrue(exists)
    
    def test_not_exists(self):
        exists = self.db.file_exists('nonexistent.txt')
        self.assertFalse(exists)


if __name__ == '__main__':
    unittest.main()
