# Authentication Log Analyzer

A Bash utility that parses system authentication logs (/var/log/auth.log or /var/log/secure) and generates a detailed summary report.
It highlights failed and successful SSH login attempts, sudo and su activity, and other authentication-related events.

## Installation

sudo cp auth-log-analyzer.sh /usr/local/sbin/auth-log-analyzer.sh  
sudo chmod 0750 /usr/local/sbin/auth-log-analyzer.sh  
sudo chown root:root /usr/local/sbin/auth-log-analyzer.sh  

## Usage

Run manually as root:  
sudo /usr/local/sbin/auth-log-analyzer.sh

Each run will:

Analyze the active authentication log (/var/log/auth.log or /var/log/secure)  
Generate a timestamped report in /var/log/auth_reports/  
Append runtime information to /var/log/auth_reports/auth-analyzer.log  

## Schedule with cron

Run hourly:  
0 * * * * /usr/local/sbin/auth-log-analyzer.sh >> /var/log/auth_reports/auth-analyzer.log 2>&1

## Report Output

Reports are stored in:  
/var/log/auth_reports/auth_report_YYYY-MM-DD_HH-MM-SS.txt

Each report includes:  
Top failed SSH IPs and usernames  
Successful SSH logins  
Local (TTY) logins  
sudo usage summary  
su switch attempts  
Totals and last 5 failed attempts

## Notes

Creates /var/log/auth_reports/ automatically if missing.  
Applies secure permissions (umask 027 and chmod 0640 on reports).  
Captures all errors and messages in a single log (auth-analyzer.log).  
Exit codes:  
0 – Run completed successfully  
1 – Fatal error (missing log file or unexpected failure)  
2 – Not used (reserved for potential warnings)  

## Example Log Output

[2025-11-14 13:00:00] === Authentication log analysis started (timestamp: 2025-11-14_13-00-00) ===  
[2025-11-14 13:00:00] Analyzing: /var/log/auth.log  
[2025-11-14 13:00:00] Report will be saved as: /var/log/auth_reports/auth_report_2025-11-14_13-00-00.txt  
[2025-11-14 13:00:02] === Authentication log analysis completed successfully (timestamp: 2025-11-14_13-00-00) ===  
[2025-11-14 13:00:02] Report saved to: /var/log/auth_reports/auth_report_2025-11-14_13-00-00.txt

## Example Report Contents

== Top 10 Failed SSH Login IPs ==  
    12 203.0.113.45  
     7 198.51.100.21  
     4 192.0.2.88  

== Sudo Usage Summary ==  
    15 user1  
     9 root  
     3 deploy  

== Summary ==  
Total failed SSH logins:      23  
Total successful SSH logins:  4  
Total sudo commands used:     18  
Total su attempts:            2