#!/usr/bin/env bash
# A bogus share token must not land on a share. The API wraps the HMAC error
# as 404 not-found (see mapShareErr in backend/internal/api/handlers_shares.go).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/emulated/common.sh"

BAD_TOKEN="not-a-real-token.abcdef"

code=$(curl -s -o /dev/null -w '%{http_code}' \
  -X POST "$BACKEND_URL/v1/shares/by-token/$BAD_TOKEN/requests" || true)

case "$code" in
  400|404|410)
    log "test_05: invalid token rejected with HTTP $code"
    ;;
  *)
    fail "expected 400/404/410 for invalid token, got HTTP $code"
    ;;
esac
