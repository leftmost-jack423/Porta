#!/usr/bin/env bash
# N emulated devices, each serves a different file. Every receiver downloads
# its device's file and verifies the sha. Exercises the tunnel hub with
# multiple concurrently-registered shares.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

N=${N:-4}
declare -a TOKENS=() FIXTURES=() SHAS=() NAMES=()

for i in $(seq 1 "$N"); do
  name="dev02_$i"
  fx="$WORKDIR/fixture_02_$i.bin"
  make_fixture "$fx" $((512 * 1024))   # 512 KiB each
  sha=$(sha256_of "$fx")
  tok=$(spawn_device "$name" "$fx")
  NAMES+=("$name"); FIXTURES+=("$fx"); SHAS+=("$sha"); TOKENS+=("$tok")
done
log "test_02: $N devices online"

# Fire every receiver request in parallel, then approve + download.
pids=()
for i in $(seq 0 $((N - 1))); do
  (
    tok=${TOKENS[$i]}; fx=${FIXTURES[$i]}; sha=${SHAS[$i]}
    sid=$(request_session "$tok")
    wait_approved "$sid" 15
    out="$WORKDIR/dl_02_$i.bin"
    download "$sid" "$(basename "$fx")" "$out"
    assert_sha "$out" "$sha"
  ) &
  pids+=($!)
done

for p in "${pids[@]}"; do
  wait "$p" || fail "a parallel receiver failed (pid $p)"
done

for n in "${NAMES[@]}"; do kill_device "$n"; done
log "test_02: $N parallel devices verified"
