#!/usr/bin/env bash
# Purpose: Analyze system authentication logs (SSH, local logins, sudo, su)
#          and generate a detailed text report.
# Usage:   sudo ./auth-log-analyzer.sh
# Logs:    /var/log/auth_reports/auth-analyzer.log

set -euo pipefail
IFS=$'\n\t'
umask 027

# Report output directory
REPORT_DIR="/var/log/auth_reports"

# Runtime paths and filenames
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
report_file="${REPORT_DIR}/auth_report_${timestamp}.txt"
main_log="${REPORT_DIR}/auth-analyzer.log"

# Helper functions

# Create directory if missing and set safe permissions
ensure_dir() {
  local dir_path="$1"
  if [[ ! -d "$dir_path" ]]; then
    mkdir -p "$dir_path"
  fi
  chmod 0750 "$dir_path" || true
}

# Write a message to stdout and log file
log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$main_log"
}

# Log an error message and exit
error_exit() {
  local msg="$1"
  printf '[%s] [ERROR] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$main_log"
  exit 1
}

trap 'error_exit "Command \"$BASH_COMMAND\" failed at line $LINENO (exit code $?)"' ERR INT TERM

# Write section headers to the report 
section() {
  local title="$1"
  printf '\n=== %s ===\n' "$title" | tee -a "$report_file"
}

# Initial setup
ensure_dir "$REPORT_DIR"

# Redirect all stderr output to the main log
exec 2>>"$main_log"

# Detect authentication log path 
if [[ -f /var/log/auth.log ]]; then
  LOG_PATH="/var/log/auth.log"
elif [[ -f /var/log/secure ]]; then
  LOG_PATH="/var/log/secure"
else
  error_exit "No authentication log found (expected /var/log/auth.log or /var/log/secure)."
fi

log ""
log "=== Authentication log analysis started (timestamp: $timestamp) ==="
log "Analyzing: $LOG_PATH"
log "Report will be saved as: $report_file"
log ""

# 1) Top 10 Failed SSH Login IPs
section "Top 10 Failed SSH Login IPs"
{
  grep "Failed password" "$LOG_PATH" |
  awk '{for (i=1;i<=NF;i++) if ($i=="from") {print $(i+1); break}}' |
  sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 2) Top 10 Failed SSH Usernames
section "Top 10 Failed SSH Usernames"
{
  grep "Failed password" "$LOG_PATH" |
  awk '{for (i=1;i<=NF;i++) if ($i=="for") {if ($(i+1)=="invalid" && $(i+2)=="user") print $(i+3); else if ($(i+1)=="invalid") print $(i+2); else print $(i+1); break }}' |
  sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 3) Top 10 Successful SSH Logins
section "Top 10 Successful SSH Logins (user ip)"
{
  grep -E "Accepted (password|publickey|keyboard-interactive)" "$LOG_PATH" |
  awk '{user=""; ip=""; for (i=1;i<=NF;i++){if ($i=="for") user=$(i+1); if ($i=="from") ip=$(i+1);} if (user!="" && ip!="") print user, ip;}' |
  sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 4) Local Logins (TTY/Console)
section "Local Logins (Console/TTY)"
{
  grep -E "session opened for user .* by .*(LOGIN|lightdm|gdm|sddm|systemd-logind)" "$LOG_PATH" |
  awk '{for (i=1;i<=NF;i++) if ($i=="user") print $(i+1)}' |
  sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 5) Sudo Usage Summary
section "Sudo Usage Summary"
{
  grep "sudo: " "$LOG_PATH" | awk -F: '{print $3}' | awk '{print $1}' | sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 6) User Switch (su) Attempts
section "User Switch (su) Attempts"
{
  grep "pam_unix(su:" "$LOG_PATH" |
  awk '{for (i=1;i<=NF;i++) if ($i=="for" && $(i+1)=="user") {print $(i+2); break}}' |
  sort | uniq -c | sort -nr | head
} | tee -a "$report_file" || true

# 7) Summary
section "Summary"
{
  total_fails=$(grep -c "Failed password" "$LOG_PATH" || true)
  total_success=$(grep -Ec "Accepted (password|publickey|keyboard-interactive)" "$LOG_PATH" || true)
  total_sudo=$(grep -c "sudo:" "$LOG_PATH" || true)
  total_su=$(grep -c "pam_unix(su:" "$LOG_PATH" || true)

  echo "Total failed SSH logins:      $total_fails"
  echo "Total successful SSH logins:  $total_success"
  echo "Total sudo commands used:     $total_sudo"
  echo "Total su attempts:            $total_su"
} | tee -a "$report_file" || true

# 8) Recent Failed Logins (last 5)
section "Recent Failed Logins (last 5)"
{
  grep "Failed password" "$LOG_PATH" | tail -n 5 || true
} | tee -a "$report_file" || true

# Finalize permissions and log
chmod 0640 "$report_file" "$main_log" || true
log "=== Authentication log analysis completed successfully (timestamp: $timestamp) ==="
log "Report saved to: $report_file"