#!/usr/bin/env bash
# One emulated device, M concurrent receivers pulling the same file. Proves
# the tunnel multiplexes OpOpen/OpBody/OpEnd by requestID correctly.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

M=${M:-5}
FIXTURE="$WORKDIR/fixture_03.bin"
make_fixture "$FIXTURE" $((1 * 1024 * 1024))   # 1 MiB
EXPECTED=$(sha256_of "$FIXTURE")

TOKEN=$(spawn_device "dev03" "$FIXTURE")

pids=()
for i in $(seq 1 "$M"); do
  (
    sid=$(request_session "$TOKEN")
    wait_approved "$sid" 15
    out="$WORKDIR/dl_03_$i.bin"
    download "$sid" "$(basename "$FIXTURE")" "$out"
    assert_sha "$out" "$EXPECTED"
  ) &
  pids+=($!)
done

for p in "${pids[@]}"; do
  wait "$p" || fail "parallel receiver $p failed"
done

kill_device "dev03"
log "test_03: $M concurrent receivers verified"
