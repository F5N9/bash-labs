# System Backup Script

Bash script to create timestamped .tar.gz backups of directories listed in /etc/backup_list.txt.
Designed for daily automated backups with basic retention and logging.

## Installation

```bash
sudo cp backup.sh /usr/local/sbin/backup.sh  
sudo chmod 0750 /usr/local/sbin/backup.sh  
sudo chown root:root /usr/local/sbin/backup.sh
```

## Configuration

Edit /etc/backup_list.txt and list one directory per line:

/etc  
/home  
/var/www

If the file doesn’t exist, the script will create an empty one and exit with a message.

## Schedule with cron

Run nightly at 3 AM:  
```bash
0 3 * * * /usr/local/sbin/backup.sh >> /var/backups/system/backup.log 2>&1
```

## Notes

Keeps the newest N backups per directory (KEEP in script, default = 5).  
Performs archive integrity checks and automatically deletes corrupted files.  
Logs everything to /var/backups/system/backup.log.  
Safe permissions (umask 027).  
Can run without root, but some directories may be skipped.  
If SELinux is enforcing, the script logs a reminder to run: restorecon -R /var/backups/system  
Exit codes:  
0 – All backups successful  
1 – Fatal error or missing configuration  
2 – Some backups failed verification (check log)  

## Example Log Output

[2025-11-14 03:00:00] === Backup job started (timestamp: 2025-11-14_03-00-00) ===  
[2025-11-14 03:00:01] Backing up /etc -> /var/backups/system/etc_2025-11-14_03-00-00.tar.gz  
[2025-11-14 03:00:02] Verified archive: /var/backups/system/etc_2025-11-14_03-00-00.tar.gz (12M)  
[2025-11-14 03:00:02] All backups verified successfully.  
[2025-11-14 03:00:02] === Backup job completed successfully ===  

