#!/usr/bin/env bash
# scripts/test-emulated.sh
#
# Automated test suite using emulated devices. The iPhone sender is replaced
# by backend/cmd/fake-sender (in-memory Ed25519 keypair, auto-approving
# stub). Each test case under scripts/emulated/test_*.sh runs against a
# single shared backend + postgres instance.
#
# Usage:
#   ./scripts/test-emulated.sh                  # run every test_*.sh
#   ./scripts/test-emulated.sh 02 04            # run only those matching
#   KEEP_LOGS=1 ./scripts/test-emulated.sh      # don't delete WORKDIR on exit
#   BACKEND_URL=http://host:8080 ...            # use an already-running backend
#                                                # (skips build & boot)
#
# Exit 0 = every selected test passed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMUDIR="$ROOT/scripts/emulated"

# shellcheck disable=SC1091
source "$EMUDIR/common.sh"

# --- config ---------------------------------------------------------------

BACKEND_URL="${BACKEND_URL:-http://localhost:8080}"
EXTERNAL_BACKEND="${EXTERNAL_BACKEND:-}"   # if non-empty, skip our own boot
KEEP_LOGS="${KEEP_LOGS:-}"
WORKDIR="${TMPDIR:-/tmp}/porta-emulated.$$"
mkdir -p "$WORKDIR"
export BACKEND_URL WORKDIR

BACKEND_PID=""

cleanup() {
  kill_all_devices || true
  [[ -n "$BACKEND_PID" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  if [[ -z "$KEEP_LOGS" ]]; then
    rm -rf "$WORKDIR"
  else
    log "logs kept in $WORKDIR"
  fi
}
trap cleanup EXIT

# --- dependencies ---------------------------------------------------------

for cmd in go docker curl jq shasum; do
  command -v "$cmd" >/dev/null || fail "$cmd not installed"
done

# --- postgres + backend ---------------------------------------------------

boot_stack() {
  local i

  log "starting postgres"
  docker compose -f "$ROOT/infra/docker-compose.yml" up -d postgres >/dev/null
  for i in $(seq 1 30); do
    if docker compose -f "$ROOT/infra/docker-compose.yml" exec -T postgres \
        pg_isready -U porta >/dev/null 2>&1; then
      break
    fi
    sleep 1
    (( i == 30 )) && fail "postgres not ready"
  done

  export PORTA_ADDR=":8080"
  export PORTA_ENV="dev"
  export PORTA_DATABASE_URL="postgres://porta:porta@localhost:5432/porta?sslmode=disable"
  export PORTA_PUBLIC_BASE_URL="$BACKEND_URL"
  export PORTA_SHARE_HMAC_SECRET="emulated-share-hmac-secret-32bytes!"
  export PORTA_JWT_SECRET="emulated-jwt-secret-32-bytes-long!"
  export PORTA_SHARE_TTL_HOURS=1
  export PORTA_JWT_TTL_MINUTES=30

  log "building backend"
  (cd "$ROOT/backend" && go build -o "$WORKDIR/porta" ./cmd/porta)

  log "running migrations"
  (cd "$ROOT/backend" && "$WORKDIR/porta" -migrate) >"$WORKDIR/migrate.log" 2>&1

  log "booting backend (logs: $WORKDIR/backend.log)"
  (cd "$ROOT/backend" && "$WORKDIR/porta") >"$WORKDIR/backend.log" 2>&1 &
  BACKEND_PID=$!

  for i in $(seq 1 30); do
    if curl -fsS "$BACKEND_URL/health" >/dev/null 2>&1; then break; fi
    sleep 0.3
    (( i == 30 )) && fail "backend did not come up — see $WORKDIR/backend.log"
  done
  ok "backend up at $BACKEND_URL"
}

if [[ -n "$EXTERNAL_BACKEND" ]]; then
  curl -fsS "$BACKEND_URL/health" >/dev/null \
    || fail "EXTERNAL_BACKEND set but $BACKEND_URL/health is unreachable"
  log "using external backend at $BACKEND_URL"
else
  boot_stack
fi

# --- build fake-sender once -----------------------------------------------

FAKE_SENDER_BIN="$WORKDIR/fake-sender"
export FAKE_SENDER_BIN
log "building fake-sender"
(cd "$ROOT/backend" && go build -o "$FAKE_SENDER_BIN" ./cmd/fake-sender)

# --- pick test cases ------------------------------------------------------

select_tests() {
  local filters=("$@")
  local f
  if (( ${#filters[@]} == 0 )); then
    ls "$EMUDIR"/test_*.sh 2>/dev/null | sort
  else
    for f in "$EMUDIR"/test_*.sh; do
      local base
      base=$(basename "$f")
      for pat in "${filters[@]}"; do
        if [[ "$base" == *"$pat"* ]]; then
          printf '%s\n' "$f"
          break
        fi
      done
    done | sort -u
  fi
}

# --- run ------------------------------------------------------------------

TESTS=()
while IFS= read -r line; do TESTS+=("$line"); done < <(select_tests "$@")

(( ${#TESTS[@]} > 0 )) || fail "no test files matched"

PASS=()
FAIL=()
for tf in "${TESTS[@]}"; do
  name=$(basename "$tf" .sh)
  log "▶ $name"
  local_log="$WORKDIR/$name.test.log"
  if bash "$tf" >"$local_log" 2>&1; then
    ok "$name"
    PASS+=("$name")
  else
    warn "$name FAILED — tail of $local_log:"
    tail -n 30 "$local_log" >&2 || true
    FAIL+=("$name")
  fi
  # Give the backend a breath and scrub lingering devices between tests.
  kill_all_devices || true
done

echo
log "summary: ${#PASS[@]} passed, ${#FAIL[@]} failed"
for n in ${PASS[@]+"${PASS[@]}"}; do ok "$n"; done
for n in ${FAIL[@]+"${FAIL[@]}"}; do warn "$n"; done

(( ${#FAIL[@]} == 0 )) || exit 1
