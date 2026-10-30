#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_DIR/lib/common.sh"

DISK_THRESHOLD=80
RAM_THRESHOLD=85

STATUS=0

echo "================================"
echo "       SERVER HEALTH CHECK"
echo "================================"

echo
echo "[HOSTNAME]"
hostname

echo
echo "[UPTIME]"
uptime

echo
echo "[CPU LOAD]"
cat /proc/loadavg

echo
echo "[MEMORY]"
free -h

RAM_USAGE=$(free | awk '/^Mem:/ {
    if ($2 > 0) printf "%.0f", $3/$2*100
}')

echo "RAM Usage: ${RAM_USAGE}%"

if (( RAM_USAGE >= RAM_THRESHOLD )); then
    log "WARNING" "RAM usage is high"
    STATUS=1
fi

echo
echo "[DISK]"
df -h

while read -r USAGE MOUNT; do

    USAGE="${USAGE%\%}"

    if (( USAGE >= DISK_THRESHOLD )); then
        log "WARNING" "Disk usage high: $MOUNT"
        STATUS=1
    fi

done < <(df -P | awk 'NR > 1 {print $(NF-1), $NF}')
echo
echo "[SERVICE STATUS]"

for SERVICE in "$@"; do

    if systemctl is-active --quiet "$SERVICE"; then
        echo "[OK] $SERVICE is running"
    else
        echo "[FAILED] $SERVICE is not running"
        STATUS=1
    fi

done

if (( STATUS == 0 )); then
    log "INFO" "Health check passed"
else
    log "WARNING" "Health check detected problems"
fi

exit "$STATUS"
