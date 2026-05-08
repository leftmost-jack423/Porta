#!/usr/bin/env bash
# scripts/emulated/common.sh
#
# Shared helpers for the emulated-device test suite. Sourced by each
# scripts/emulated/test_*.sh case and by the orchestrator.
#
# Conventions:
#   - BACKEND_URL        exported by the orchestrator (default http://localhost:8080)
#   - FAKE_SENDER_BIN    path to the compiled backend/cmd/fake-sender
#   - WORKDIR            per-run scratch dir (logs, fixtures, downloads)
#   - Each helper logs via log / fail and returns 0 on success.

set -euo pipefail

# --- logging ---------------------------------------------------------------

_color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
log()    { printf '%s %s\n' "$(_color '36' "[$(date +%H:%M:%S)]")" "$*"; }
warn()   { printf '%s %s\n' "$(_color '33' "[warn]")" "$*" >&2; }
fail()   { printf '%s %s\n' "$(_color '31' "[fail]")" "$*" >&2; exit 1; }
ok()     { printf '%s %s\n' "$(_color '32' "[ ok ]")" "$*"; }

# --- fixtures --------------------------------------------------------------

# make_fixture <path> <size_bytes> — creates a deterministic-ish random file.
make_fixture() {
  local path=$1
  local size=$2
  # dd block size tuning: use 1MiB chunks when size is large to stay snappy.
  if (( size >= 1048576 )); then
    local mib=$(( size / 1048576 ))
    dd if=/dev/urandom of="$path" bs=1048576 count="$mib" status=none
  else
    dd if=/dev/urandom of="$path" bs="$size" count=1 status=none
  fi
}

sha256_of() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# --- emulated-device lifecycle --------------------------------------------

# spawn_device <name> <file> — launches a fake-sender background process. Writes
# logs to $WORKDIR/<name>.log and records its PID in $WORKDIR/<name>.pid.
# Echoes the share token on success.
spawn_device() {
  local name=$1
  local file=$2
  local logf="$WORKDIR/$name.log"
  : >"$logf"

  "$FAKE_SENDER_BIN" -backend "$BACKEND_URL" -file "$file" -title "$name" \
    >"$logf" 2>&1 &
  echo $! >"$WORKDIR/$name.pid"

  # Wait for tunnel to open (up to 10s).
  local i
  for i in $(seq 1 50); do
    if grep -q "tunnel open" "$logf" 2>/dev/null; then break; fi
    sleep 0.2
    if (( i == 50 )); then
      fail "device '$name' tunnel did not open — see $logf"
    fi
  done

  local share_url
  share_url=$(grep "share url:" "$logf" | awk '{print $3}' | head -1)
  [[ -n "$share_url" ]] || fail "device '$name' did not print share url — see $logf"
  printf '%s\n' "${share_url##*/s/}"
}

# kill_device <name> — stops a device started by spawn_device.
kill_device() {
  local name=$1
  local pidf="$WORKDIR/$name.pid"
  [[ -f "$pidf" ]] || return 0
  local pid
  pid=$(cat "$pidf")
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$pidf"
}

# kill_all_devices — best-effort cleanup; safe to call from a trap.
kill_all_devices() {
  local pidf
  shopt -s nullglob
  for pidf in "$WORKDIR"/*.pid; do
    local pid
    pid=$(cat "$pidf" 2>/dev/null || true)
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null || true
    rm -f "$pidf"
  done
  shopt -u nullglob
  wait 2>/dev/null || true
}

# --- receiver flow ---------------------------------------------------------

# request_session <token> — POSTs a receiver request, echoes the session id.
request_session() {
  local token=$1
  local resp sid
  resp=$(curl -fsS -X POST "$BACKEND_URL/v1/shares/by-token/$token/requests")
  sid=$(printf '%s' "$resp" | jq -r .session_id)
  [[ -n "$sid" && "$sid" != "null" ]] || fail "no session id in response: $resp"
  printf '%s\n' "$sid"
}

# wait_approved <session_id> [timeout_s=10] — polls until approved.
wait_approved() {
  local sid=$1 timeout=${2:-10}
  local deadline=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < deadline )); do
    local status
    status=$(curl -fsS "$BACKEND_URL/v1/sessions/$sid/status" | jq -r .status)
    [[ "$status" == "approved" ]] && return 0
    sleep 0.2
  done
  fail "session $sid not approved within ${timeout}s"
}

# download <session_id> <filename> <out_path> — runs curl, fails on non-2xx.
download() {
  local sid=$1 filename=$2 out=$3
  curl -fsS "$BACKEND_URL/p/$sid/files/$filename" -o "$out"
}

# assert_sha <path> <expected> — dies on mismatch.
assert_sha() {
  local path=$1 expected=$2 actual
  actual=$(sha256_of "$path")
  if [[ "$actual" != "$expected" ]]; then
    fail "sha mismatch for $path: expected $expected got $actual"
  fi
}
