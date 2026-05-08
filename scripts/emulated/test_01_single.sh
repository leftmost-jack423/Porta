#!/usr/bin/env bash
# Baseline: one emulated device, one receiver, 2 MiB file, sha256 match.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

FIXTURE="$WORKDIR/fixture_01.bin"
make_fixture "$FIXTURE" $((2 * 1024 * 1024))
EXPECTED=$(sha256_of "$FIXTURE")

TOKEN=$(spawn_device "dev01" "$FIXTURE")
SID=$(request_session "$TOKEN")
wait_approved "$SID"

OUT="$WORKDIR/dl_01.bin"
download "$SID" "$(basename "$FIXTURE")" "$OUT"
assert_sha "$OUT" "$EXPECTED"

kill_device "dev01"
log "test_01: 2MiB transfer verified"
