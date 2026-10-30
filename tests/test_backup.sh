#!/bin/bash

set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

TEST_DIR="$(mktemp -d)"

trap 'rm -rf "$TEST_DIR"' EXIT

SOURCE="$TEST_DIR/source"
BACKUP="$TEST_DIR/backups"
RESTORE="$TEST_DIR/restore"

mkdir -p "$SOURCE"

echo "SysAdmin Backup Test" > "$SOURCE/test.txt"

echo "[TEST 1] Creating backup"

bash "$PROJECT_DIR/scripts/backup.sh" \
    "$SOURCE" "$BACKUP"

ARCHIVE="$(find "$BACKUP" -name 'backup-*.tar.gz' -type f | head -n 1)"

[[ -f "$ARCHIVE" ]] || {
    echo "FAILED: Backup not created"
    exit 1
}

echo "[TEST 2] Checking checksum"

(
    cd "$BACKUP"
    sha256sum -c "$(basename "$ARCHIVE").sha256"
)

echo "[TEST 3] Restoring backup"

bash "$PROJECT_DIR/scripts/restore.sh" \
    "$ARCHIVE" "$RESTORE"

echo "[TEST 4] Comparing files"

cmp "$SOURCE/test.txt" "$RESTORE/source/test.txt"

echo
echo "ALL TESTS PASSED"
