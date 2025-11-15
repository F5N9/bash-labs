#!/usr/bin/env bash
# Purpose: Create timestamped .tar.gz backups for a set of directories listed in a config file
#          and keep only the newest N archives per source directory.
# Usage:   sudo ./backup.sh
# Logs:	   /var/backups/system/backup.log

set -euo pipefail
IFS=$'\n\t'
umask 027   

# List of directories to back up
CONFIG_FILE="/etc/backup_list.txt"

# Backup destination directory 
DEST_DIR="/var/backups/system"

# Number of recent archives to keep 
KEEP=5

# Runtime paths and filenames
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
log_file="${DEST_DIR}/backup.log"

# Helper functions

# Warn if not running as root
warn_if_not_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "[WARN] Running without root. Some paths may be unreadable (permission denied)." | tee -a "$log_file"
  fi
}

# Create directory if missing and set safe permissions
ensure_dir() {
  local dir_path="$1"
  if [[ ! -d "$dir_path" ]]; then
    mkdir -p "$dir_path"
  fi
  chmod 0750 "$dir_path" || true
}

# Write a message to stdout and the log file
log() {
  local msg="$1"
  printf '[%s] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$log_file"
}

# Log an error message and exit
error_exit() {
  local msg="$1"
  printf '[%s] [ERROR] %s\n' "$(date '+%F %T')" "$msg" | tee -a "$log_file"
  exit 1
}

# Verify the config file exists and is not empty
check_config_file() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
    log "Config file not found - created empty file at: $CONFIG_FILE"
    log "Please add directories to back up (one absolute path per line)."
    exit 1
  fi

  if [[ ! -s "$CONFIG_FILE" ]]; then
    log "Config file $CONFIG_FILE exists but is empty."
    log "Please add directories to back up (one absolute path per line)."
    exit 1
  fi
}

trap 'error_exit "Command \"$BASH_COMMAND\" failed at line $LINENO (exit code $?)"' ERR INT TERM

# Initial checks
warn_if_not_root
ensure_dir "$DEST_DIR"
check_config_file

# Send all stderr output to the log file
exec 2>>"$log_file"

# SELinux notice (RHEL-based systems)
# Logs a reminder if SELinux is enforcing — no action needed on non-SELinux systems
if command -v getenforce >/dev/null 2>&1 && [[ $(getenforce 2>/dev/null || echo Permissive) == "Enforcing" ]]; then
  log "SELinux is enforcing. If contexts differ, you may need: restorecon -R $DEST_DIR"
fi

log ""
log "=== Backup job started (timestamp: $timestamp) ==="
log ""

# Track directories that failed verification
failed_backups=()

# Main loop over each source directory
while IFS= read -r source_dir || [[ -n "$source_dir" ]]; do
  # Skip comments and blank lines
  [[ -z "$source_dir" || "$source_dir" =~ ^[[:space:]]*# ]] && continue

  if [[ ! -d "$source_dir" ]]; then
    log "[WARN] Skipping missing directory: $source_dir"
    continue
  fi

  # Use directory name (no path) for archive filename, replacing spaces with underscores
  backup_name="$(basename "$source_dir" | tr ' ' '_')"
  backup_file="${DEST_DIR}/${backup_name}_${timestamp}.tar.gz"

  log "Backing up $source_dir -> $backup_file"

  # Create compressed archive for the source directory (use -C to avoid full paths inside)
  if ! tar -czf "$backup_file" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"; then
    log "[ERROR] Failed to create archive for: $source_dir"
    failed_backups+=("$source_dir")
    continue
  fi

  # Verify archive integrity
  if tar -tzf "$backup_file" >/dev/null 2>&1; then
    size=$(du -h "$backup_file" | cut -f1)
    chmod 0640 "$backup_file" || true
    log "Verified archive: $backup_file ($size)"
  else
    log "[ERROR] Archive verification failed: $backup_file — removing corrupt file"
    rm -f "$backup_file"
    failed_backups+=("$source_dir")
    continue
  fi

  # Keep only the newest $KEEP backups for this source
  # Older archives are identified by modification time and deleted
  mapfile -d '' files < <(
    find "$DEST_DIR" -maxdepth 1 -type f -name "${backup_name}_*.tar.gz" \
      -printf '%T@\t%p\0' | sort -zrn | cut -f2- -z
  )

  # Remove older backups beyond the $KEEP limit
  if (( ${#files[@]} > KEEP )); then
    for ((i=KEEP; i<${#files[@]}; i++)); do
      old_backup_files=${files[$i]}
      log "Pruning old archive: $old_backup_files"
      rm -f -- "$old_backup_files" || log "[WARN] Failed to remove $old_backup_files"
    done
  fi

done < "$CONFIG_FILE"

# Backup summary
if (( ${#failed_backups[@]} > 0 )); then
  log "[WARN] Some backups failed verification:"
  for dir in "${failed_backups[@]}"; do
    log "  - $dir"
  done
  log "=== Backup job completed with warnings (timestamp: $timestamp) ==="
  exit 2
else
  log "All backups verified successfully."
  log "=== Backup job completed successfully (timestamp: $timestamp) ==="
fi