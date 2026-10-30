#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/common.sh"

SOURCE_DIR="${1:-}"
BACKUP_DIR="${2:-$PROJECT_DIR/backups}"
RETENTION=7

# Validate input
if [[ -z "$SOURCE_DIR" ]]; then
    echo "Usage: $0 <source_directory> [backup_directory]"
    exit 2
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
    die "Source directory does not exist"
fi

SOURCE_DIR="$(realpath "$SOURCE_DIR")"

mkdir -p "$BACKUP_DIR"
BACKUP_DIR="$(realpath "$BACKUP_DIR")"

if [[ "$BACKUP_DIR" == "$SOURCE_DIR" ||
      "$BACKUP_DIR" == "$SOURCE_DIR/"* ||
      "$SOURCE_DIR" == "$BACKUP_DIR/"* ]]; then
    die "Source and backup directories overlap"
fi

require_cmd tar
require_cmd sha256sum

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

ARCHIVE="$BACKUP_DIR/backup-$TIMESTAMP.tar.gz"
TEMP_FILE="$(mktemp "$BACKUP_DIR/.backup.XXXXXX")"
CHECKSUM_TEMP="$TEMP_FILE.sha256"

cleanup() {
    rm -f -- "$TEMP_FILE" "$CHECKSUM_TEMP"
}

trap cleanup EXIT
LOG_FILE="$BACKUP_DIR/backup.log"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

log "Starting backup"
log "Source: $SOURCE_DIR"

# Create archive
if tar -czf "$TEMP_FILE" \
    -C "$(dirname "$SOURCE_DIR")" \
    "$(basename "$SOURCE_DIR")"; then

    log "Archive created successfully"
else
    die "Backup failed"
fi

# Verify archive
if ! tar -tzf "$TEMP_FILE" >/dev/null 2>&1; then
    die "Archive verification failed"
fi

# Generate checksum
HASH=$(sha256sum "$TEMP_FILE" | awk '{print $1}')

printf '%s  %s\n' \
    "$HASH" \
    "$(basename "$ARCHIVE")" \
    > "$CHECKSUM_TEMP"
mv "$TEMP_FILE" "$ARCHIVE"
mv "$CHECKSUM_TEMP" "$ARCHIVE.sha256"

log "Backup completed: $ARCHIVE"

# Retention policy
mapfile -t BACKUPS < <(
    find "$BACKUP_DIR" -maxdepth 1 \
        -type f -name 'backup-*.tar.gz' \
        -printf '%f\n' | sort -r
)

if (( ${#BACKUPS[@]} > RETENTION )); then
    for ((i=RETENTION; i<${#BACKUPS[@]}; i++)); do

        rm -f "$BACKUP_DIR/${BACKUPS[$i]}"
        rm -f "$BACKUP_DIR/${BACKUPS[$i]}.sha256"

        log "Removed old backup: ${BACKUPS[$i]}"
    done
fi

log "Backup process finished"

exit 0
