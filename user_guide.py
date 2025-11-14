#!/usr/bin/env python3
"""
Rapiba User Guide - Interaktives Tutorial und Beispiele
"""

def print_welcome():
    print("""
╔═══════════════════════════════════════════════════════════╗
║           Welcome to Rapiba - User Guide                  ║
║        Automated Raspberry Pi Backup System               ║
╚═══════════════════════════════════════════════════════════╝

This guide will help you get started with Rapiba.

Press Enter to continue...
    """)
    input()

def scenario_1():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 1: Simple USB Backup                              │
│ Automatically backup USB stick to /backup                  │
└─────────────────────────────────────────────────────────────┘

CONFIGURATION:
    BACKUP_SOURCES=/media/usb
    BACKUP_TARGET=/backup
    BACKUP_PATH_FORMAT=datetime
    DUPLICATE_CHECK_METHOD=sha256

RESULT STRUCTURE:
    /backup/
    ├── 2025-11-14_10-30-45/
    │   ├── file1.txt
    │   ├── folder/
    │   │   └── file2.pdf
    │   └── ...
    └── 2025-11-14_15-22-10/
        └── ...

USAGE:
    1. Plug in USB stick
    2. Automatic backup starts in background
    3. Monitor: journalctl -u rapiba -f
    4. Check: rapiba --list-backups

    """)
    input("Press Enter to continue...")

def scenario_2():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 2: Numbered Backups with Cleanup                  │
│ Keep only last 5 backups, delete older than 30 days        │
└─────────────────────────────────────────────────────────────┘

CONFIGURATION:
    BACKUP_SOURCES=/media/usb,/media/sdcard
    BACKUP_TARGET=/backup
    BACKUP_PATH_FORMAT=number
    DUPLICATE_CHECK_METHOD=md5
    DELETE_OLD_BACKUPS_DAYS=30
    MAX_BACKUPS_PER_SOURCE=5

RESULT STRUCTURE:
    /backup/
    ├── backup_1/      (oldest, will be deleted after 30 days)
    ├── backup_2/
    ├── backup_3/      (latest)
    └── (more entries)

BENEFITS:
    - Automatic cleanup saves disk space
    - Numbered format is easier to navigate
    - MD5 is faster than SHA256
    - Perfect for regular backups

COMMANDS:
    rapiba --stats          # See backup statistics
    rapiba --list-devices   # Show connected devices

    """)
    input("Press Enter to continue...")

def scenario_3():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 3: Organize by Date and Source                    │
│ Keep backups organized by date and device name             │
└─────────────────────────────────────────────────────────────┘

CONFIGURATION:
    BACKUP_SOURCES=/media/usb,/media/sdcard
    BACKUP_TARGET=/backup
    BACKUP_PATH_FORMAT=custom
    CUSTOM_PATH_FORMAT={date}/{source}_{number}
    DUPLICATE_CHECK_METHOD=sha256
    PARALLEL_JOBS=2

RESULT STRUCTURE:
    /backup/
    ├── 2025-11-14/
    │   ├── usb_1/
    │   │   ├── photos/
    │   │   ├── documents/
    │   │   └── ...
    │   └── sdcard_1/
    │       └── ...
    ├── 2025-11-15/
    │   ├── usb_2/
    │   │   └── ...
    │   └── sdcard_1/
    │       └── ...
    └── ...

ADVANTAGES:
    - Easy date-based navigation
    - Device name in path for clarity
    - Perfect for multiple source devices
    - Good for archival

COMMANDS:
    ls -la /backup/2025-11-14/
    du -sh /backup/2025-11-14/usb_1/

    """)
    input("Press Enter to continue...")

def scenario_4():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ SCENARIO 4: Fast Incremental Backups                       │
│ Quick backups with minimal duplicate checking               │
└─────────────────────────────────────────────────────────────┘

CONFIGURATION:
    BACKUP_SOURCES=/media/external_drive
    BACKUP_TARGET=/backup
    BACKUP_PATH_FORMAT=number
    DUPLICATE_CHECK_METHOD=size_time
    PARALLEL_JOBS=4
    VERIFY_CHECKSUMS=no

PERFORMANCE:
    - ~50% faster than SHA256
    - Good for frequent backups
    - Uses file size + modification time

TRADE-OFFS:
    - Less reliable duplicate detection
    - Could copy identical files twice
    - Better for non-critical data

WHEN TO USE:
    - Large file collections
    - Frequent backups on slow hardware
    - When speed is more important than safety

COMMANDS:
    time rapiba --backup-now
    # Check how much time it takes

    """)
    input("Press Enter to continue...")

def commands_reference():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ COMMAND REFERENCE                                           │
└─────────────────────────────────────────────────────────────┘

MANUAL BACKUP:
    rapiba --backup-now
    rapiba --backup-now /media/usb

LIST DEVICES:
    rapiba --list-devices

LIST BACKUPS:
    rapiba --list-backups

SERVICE MANAGEMENT:
    systemctl start rapiba           # Start service
    systemctl stop rapiba            # Stop service
    systemctl restart rapiba         # Restart service
    systemctl status rapiba          # Check status
    systemctl enable rapiba          # Enable autostart
    systemctl disable rapiba         # Disable autostart

LOGS:
    journalctl -u rapiba -f          # Live logs
    journalctl -u rapiba -n 50       # Last 50 lines
    journalctl -u rapiba --since "2 hours ago"
    tail -f /var/log/rapiba/*.log

ADMIN TOOLS:
    rapiba_admin --stats             # Backup statistics
    rapiba_admin --db-stats          # Database statistics
    rapiba_admin --clean 30          # Delete backups > 30 days old
    rapiba_admin --reset-db          # Reset duplicate database

CONFIGURATION:
    nano /etc/rapiba/rapiba.conf     # Edit config
    cp /etc/rapiba/rapiba.conf.backup /etc/rapiba/rapiba.conf

DATABASE:
    sqlite3 /var/lib/rapiba/duplicate_db.sqlite3
    > SELECT COUNT(*) FROM file_hashes;
    > SELECT * FROM file_hashes LIMIT 10;

    """)
    input("Press Enter to continue...")

def troubleshooting_quick():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ QUICK TROUBLESHOOTING                                       │
└─────────────────────────────────────────────────────────────┘

PROBLEM: Backups don't start automatically
SOLUTION:
    1. Check if service is running:
       systemctl status rapiba
    2. Check logs:
       journalctl -u rapiba -f
    3. Test with manual backup:
       rapiba --backup-now /media/usb

PROBLEM: Backup is very slow
SOLUTION:
    1. Increase parallel jobs in config:
       PARALLEL_JOBS=4
    2. Use faster duplicate method:
       DUPLICATE_CHECK_METHOD=size_time
    3. Disable verification:
       VERIFY_CHECKSUMS=no

PROBLEM: Permission errors
SOLUTION:
    1. Check backup directory permissions:
       ls -la /backup
    2. Fix permissions:
       sudo chmod 755 /backup
       sudo chown root:root /backup

PROBLEM: Disk full
SOLUTION:
    1. Enable automatic cleanup:
       DELETE_OLD_BACKUPS_DAYS=30
       MAX_BACKUPS_PER_SOURCE=5
    2. Or manually delete old backups:
       rm -rf /backup/backup_1

PROBLEM: Duplicates not detected
SOLUTION:
    1. Reset database:
       sudo rm /var/lib/rapiba/duplicate_db.sqlite3
       sudo systemctl restart rapiba

Full troubleshooting guide: /path/to/TROUBLESHOOTING.md

    """)
    input("Press Enter to continue...")

def tips_and_tricks():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ TIPS & TRICKS                                               │
└─────────────────────────────────────────────────────────────┘

TIP 1: Monitor backups in real-time
    watch -n 1 'du -sh /backup/* | tail -5'

TIP 2: Find largest backups
    du -sh /backup/* | sort -h | tail -10

TIP 3: Count files in backup
    find /backup/backup_1 -type f | wc -l

TIP 4: Check backup integrity
    find /backup/backup_1 -type f -exec md5sum {} \\; > /tmp/checksums.txt
    md5sum -c /tmp/checksums.txt

TIP 5: Schedule regular backups
    Edit rapiba-backup.timer:
        sudo nano /etc/systemd/system/rapiba-backup.timer
    Change OnCalendar to:
        OnCalendar=*-*-* 02:00:00  # 2 AM daily
    Enable:
        sudo systemctl enable rapiba-backup.timer
        sudo systemctl start rapiba-backup.timer

TIP 6: Compress old backups to save space
    tar -czf /backup/backup_1.tar.gz /backup/backup_1/
    rm -rf /backup/backup_1

TIP 7: Backup to remote location (NFS/SMB)
    BACKUP_TARGET=/mnt/nas/backups
    (mount NFS/SMB first)

TIP 8: Monitor with custom script
    Create /usr/local/bin/backup_monitor:
        while true; do
            df -h /backup
            sleep 60
        done
    Run: backup_monitor

    """)
    input("Press Enter to continue...")

def next_steps():
    print("""
┌─────────────────────────────────────────────────────────────┐
│ NEXT STEPS                                                  │
└─────────────────────────────────────────────────────────────┘

1. INSTALL RAPIBA:
   sudo bash install.sh

2. VERIFY INSTALLATION:
   sudo bash verify_installation.sh

3. QUICK SETUP:
   sudo bash quicksetup.sh

4. CHOOSE YOUR SCENARIO:
   - Scenario 1: Simple date-based backups
   - Scenario 2: Numbered with auto-cleanup
   - Scenario 3: Organized by date + source
   - Scenario 4: Fast incremental backups

5. CONFIGURE:
   nano /etc/rapiba/rapiba.conf

6. TEST:
   rapiba --backup-now /media/usb

7. ENABLE SERVICE:
   systemctl enable rapiba
   systemctl start rapiba

8. MONITOR:
   journalctl -u rapiba -f

DOCUMENTATION:
    README.md              - Full documentation
    TROUBLESHOOTING.md     - Common issues
    PERFORMANCE.md         - Performance tuning
    EXAMPLES.conf          - Configuration examples
    rapiba --help          - Command help

    """)

def main():
    import sys
    
    print_welcome()
    
    while True:
        print("""
╔═══════════════════════════════════════════════════════════╗
║              Choose a Topic                               ║
╚═══════════════════════════════════════════════════════════╝

1. Simple USB Backup (Scenario 1)
2. Numbered Backups with Cleanup (Scenario 2)
3. Organize by Date & Source (Scenario 3)
4. Fast Incremental Backups (Scenario 4)
5. Command Reference
6. Quick Troubleshooting
7. Tips & Tricks
8. Next Steps
0. Exit

Enter your choice (0-8): """)
        
        choice = input().strip()
        
        if choice == '1':
            scenario_1()
        elif choice == '2':
            scenario_2()
        elif choice == '3':
            scenario_3()
        elif choice == '4':
            scenario_4()
        elif choice == '5':
            commands_reference()
        elif choice == '6':
            troubleshooting_quick()
        elif choice == '7':
            tips_and_tricks()
        elif choice == '8':
            next_steps()
            break
        elif choice == '0':
            print("\nThank you for using Rapiba!")
            break
        else:
            print("Invalid choice. Please try again.\n")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nGoodbye!")
