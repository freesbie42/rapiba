#!/usr/bin/env python3
"""
Rapiba Admin - Verwaltungswerkzeug für Backups
"""

import os
import sys
import argparse
import sqlite3
from pathlib import Path
from datetime import datetime, timedelta
import subprocess

# Optional: tabulate für schönere Tabellen
try:
    from tabulate import tabulate
    HAS_TABULATE = True
except ImportError:
    HAS_TABULATE = False

sys.path.insert(0, '/usr/local/lib/rapiba')
from backup_handler import Config, DuplicateDB


def print_backup_stats(backup_target):
    """Zeigt Statistiken der Backups"""
    if not os.path.exists(backup_target):
        print(f"Backup-Verzeichnis existiert nicht: {backup_target}")
        return
    
    backups = []
    for entry in os.listdir(backup_target):
        backup_path = os.path.join(backup_target, entry)
        if os.path.isdir(backup_path):
            stat = os.stat(backup_path)
            created = datetime.fromtimestamp(stat.st_ctime)
            
            # Berechne Größe
            total_size = 0
            file_count = 0
            for root, dirs, files in os.walk(backup_path):
                for file in files:
                    file_path = os.path.join(root, file)
                    total_size += os.path.getsize(file_path)
                    file_count += 1
            
            backups.append({
                'Name': entry,
                'Erstellt': created.strftime('%Y-%m-%d %H:%M:%S'),
                'Größe (MB)': f"{total_size / 1024 / 1024:.2f}",
                'Dateien': file_count
            })
    
    if backups:
        print("\n=== Backup-Übersicht ===\n")
        if HAS_TABULATE:
            print(tabulate(backups, headers='keys', tablefmt='grid'))
        else:
            # Fallback ohne tabulate
            print(f"{'Name':<40} {'Erstellt':<20} {'Größe (MB)':<12} {'Dateien':<8}")
            print("-" * 80)
            for b in backups:
                print(f"{b['Name']:<40} {b['Erstellt']:<20} {b['Größe (MB)']:<12} {b['Dateien']:<8}")
        total_size = sum(float(b['Größe (MB)']) for b in backups)
        total_files = sum(b['Dateien'] for b in backups)
        print(f"\nGesamt: {len(backups)} Backups, {total_size:.2f} MB, {total_files} Dateien")
    else:
        print("Keine Backups gefunden")


def print_duplicate_stats(db_path):
    """Zeigt Statistiken der Duplikat-Datenbank"""
    if not os.path.exists(db_path):
        print("Duplikat-Datenbank existiert nicht")
        return
    
    db = DuplicateDB(db_path)
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute('SELECT COUNT(*) FROM file_hashes')
    total_files = cursor.fetchone()[0]
    
    cursor.execute('SELECT SUM(filesize) FROM file_hashes')
    total_size = cursor.fetchone()[0] or 0
    
    cursor.execute('SELECT DISTINCT source_path FROM file_hashes')
    sources = [row[0] for row in cursor.fetchall()]
    
    conn.close()
    
    print("\n=== Duplikat-Datenbank ===\n")
    print(f"Erfasste Dateien: {total_files}")
    print(f"Gesamtgröße: {total_size / 1024 / 1024:.2f} MB")
    print(f"Quellen: {', '.join(sources)}")


def clean_old_backups(backup_target, days):
    """Löscht Backups älter als X Tage"""
    if not os.path.exists(backup_target):
        print(f"Backup-Verzeichnis existiert nicht: {backup_target}")
        return
    
    cutoff_date = datetime.now() - timedelta(days=days)
    deleted_count = 0
    
    for entry in os.listdir(backup_target):
        backup_path = os.path.join(backup_target, entry)
        if os.path.isdir(backup_path):
            stat = os.stat(backup_path)
            created = datetime.fromtimestamp(stat.st_ctime)
            
            if created < cutoff_date:
                print(f"Lösche: {entry}")
                import shutil
                shutil.rmtree(backup_path)
                deleted_count += 1
    
    print(f"\n{deleted_count} alte Backups gelöscht")


def reset_duplicate_db(db_path):
    """Setzt die Duplikat-Datenbank zurück"""
    if os.path.exists(db_path):
        os.remove(db_path)
        print(f"Duplikat-Datenbank gelöscht: {db_path}")
    else:
        print("Duplikat-Datenbank existiert nicht")


def main():
    parser = argparse.ArgumentParser(description='Rapiba Admin - Verwaltungstool')
    parser.add_argument('--config', '-c', default='/etc/rapiba/rapiba.conf',
                       help='Konfigurationsdatei')
    parser.add_argument('--stats', '-s', action='store_true',
                       help='Zeige Backup-Statistiken')
    parser.add_argument('--db-stats', action='store_true',
                       help='Zeige Duplikat-DB Statistiken')
    parser.add_argument('--clean', type=int, metavar='DAYS',
                       help='Lösche Backups älter als X Tage')
    parser.add_argument('--reset-db', action='store_true',
                       help='Setze Duplikat-Datenbank zurück')
    
    args = parser.parse_args()
    
    config = Config(args.config)
    
    if args.stats:
        print_backup_stats(config.get('BACKUP_TARGET'))
    
    if args.db_stats:
        print_duplicate_stats(config.get('DUPLICATE_DB_PATH'))
    
    if args.clean:
        clean_old_backups(config.get('BACKUP_TARGET'), args.clean)
    
    if args.reset_db:
        if input("Wirklich Duplikat-Datenbank zurücksetzen? (ja/nein): ").lower() == 'ja':
            reset_duplicate_db(config.get('DUPLICATE_DB_PATH'))


if __name__ == '__main__':
    main()
