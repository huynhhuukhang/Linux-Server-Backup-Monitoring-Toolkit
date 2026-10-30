#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/common.sh"

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <backup.tar.gz> <restore_directory>"
    exit 2
fi

ARCHIVE="$(realpath "$1")"
RESTORE_DIR="$2"

if [[ ! -f "$ARCHIVE" ]]; then
    die "Backup archive not found"
fi

require_cmd tar
require_cmd sha256sum

CHECKSUM_FILE="$ARCHIVE.sha256"

if [[ ! -f "$CHECKSUM_FILE" ]]; then
    die "Checksum file not found"
fi

log "Verifying backup checksum"

(
    cd "$(dirname "$ARCHIVE")"
    sha256sum -c "$(basename "$CHECKSUM_FILE")"
) || die "Checksum verification failed"

log "Checking archive integrity"

tar -tzf "$ARCHIVE" >/dev/null || die "Invalid archive"

mkdir -p "$RESTORE_DIR"

RESTORE_DIR="$(realpath "$RESTORE_DIR")"

log "Starting restore"

tar --no-same-owner --no-same-permissions \
    -xzf "$ARCHIVE" -C "$RESTORE_DIR" \
    || die "Restore failed"

log "Restore completed successfully"

exit 0
