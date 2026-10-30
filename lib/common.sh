#!/bin/bash

log() {
    local LEVEL="$1"
    shift

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$LEVEL] $*" >&2
}

die() {
    log "ERROR" "$*"
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Command not found: $1"
}
