#!/usr/bin/env bash
# Sender dies before any download. Receiver request should still succeed
# (session created), but /p/.../files/... must return 502 sender offline.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

FIXTURE="$WORKDIR/fixture_04.bin"
make_fixture "$FIXTURE" $((64 * 1024))

TOKEN=$(spawn_device "dev04" "$FIXTURE")
SID=$(request_session "$TOKEN")
# Session is pending; approval happens from within fake-sender. We want the
# approval to land first, then kill the tunnel so /p/ finds no sender.
wait_approved "$SID" 10

kill_device "dev04"
# Give the backend a moment to notice the websocket close.
sleep 0.8

OUT="$WORKDIR/dl_04.bin"
code=$(curl -s -o "$OUT" -w '%{http_code}' \
  "$BACKEND_URL/p/$SID/files/$(basename "$FIXTURE")" || true)

if [[ "$code" != "502" ]]; then
  fail "expected 502 after sender offline, got HTTP $code (body: $(head -c 200 "$OUT" 2>/dev/null || true))"
fi
log "test_04: sender-offline produced HTTP 502 as expected"
