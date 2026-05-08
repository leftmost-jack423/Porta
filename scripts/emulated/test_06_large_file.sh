#!/usr/bin/env bash
# 50 MiB integrity check. Exercises frame-batching and sustained streaming
# through the tunnel. Skippable via SKIP_LARGE=1 on constrained runners.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

if [[ -n "${SKIP_LARGE:-}" ]]; then
  log "test_06: skipped (SKIP_LARGE=$SKIP_LARGE)"
  exit 0
fi

SIZE_MIB=${SIZE_MIB:-50}
FIXTURE="$WORKDIR/fixture_06.bin"
make_fixture "$FIXTURE" $((SIZE_MIB * 1024 * 1024))
EXPECTED=$(sha256_of "$FIXTURE")

TOKEN=$(spawn_device "dev06" "$FIXTURE")
SID=$(request_session "$TOKEN")
wait_approved "$SID" 20

OUT="$WORKDIR/dl_06.bin"
# Large file needs a longer curl timeout than the helper's default.
curl -fsS --max-time 120 \
  "$BACKEND_URL/p/$SID/files/$(basename "$FIXTURE")" -o "$OUT"

assert_sha "$OUT" "$EXPECTED"
kill_device "dev06"
log "test_06: ${SIZE_MIB}MiB transfer verified"
