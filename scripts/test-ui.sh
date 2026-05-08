#!/usr/bin/env bash
# scripts/test-ui.sh
#
# End-to-end UI tests for the web receiver. Uses Playwright with the /v1/* and
# /p/* endpoints mocked at the browser-route layer — no backend is required.
#
# The Playwright config runs `npm run build && npm run preview` itself, so
# this script's job is: (1) ensure node_modules + browsers are installed,
# (2) run `playwright test`, and (3) surface the HTML report path on failure.
#
# Usage:
#   ./scripts/test-ui.sh                       # run everything
#   ./scripts/test-ui.sh landing               # run only tests matching
#   ./scripts/test-ui.sh --project=iphone-14   # pass-through flags
#   HEADED=1 ./scripts/test-ui.sh              # run with a visible browser
#   UPDATE_BROWSERS=1 ./scripts/test-ui.sh     # force browser (re)install

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT/web"

_color() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
log()  { printf '%s %s\n' "$(_color '36' "[$(date +%H:%M:%S)]")" "$*"; }
fail() { printf '%s %s\n' "$(_color '31' "[fail]")" "$*" >&2; exit 1; }
ok()   { printf '%s %s\n' "$(_color '32' "[ ok ]")" "$*"; }

command -v node >/dev/null || fail "node not installed"
command -v npm  >/dev/null || fail "npm not installed"

cd "$WEB"

# 1. Install deps if the lockfile is fresher than node_modules, or it's missing.
if [[ ! -d node_modules ]] || [[ package.json -nt node_modules ]] || [[ package-lock.json -nt node_modules ]] 2>/dev/null; then
  log "installing npm deps"
  npm install --no-audit --no-fund
fi

# 2. Ensure Playwright browsers are present. The install is idempotent and
#    cheap after the first run, so we only skip it when the cache looks intact.
PW_CACHE="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"
if [[ -n "${UPDATE_BROWSERS:-}" ]] || ! ls "$PW_CACHE"/chromium-* >/dev/null 2>&1; then
  log "installing Playwright chromium"
  npx playwright install chromium
fi

# 3. Collect pass-through args. Bare tokens (no leading dash) become --grep
#    filters so `./scripts/test-ui.sh landing` just works.
ARGS=()
for a in "$@"; do
  if [[ "$a" == -* ]]; then
    ARGS+=("$a")
  else
    ARGS+=("--grep" "$a")
  fi
done
[[ -n "${HEADED:-}" ]] && ARGS+=("--headed")

log "running Playwright"
if npx playwright test ${ARGS[@]+"${ARGS[@]}"}; then
  ok "UI tests passed"
else
  code=$?
  fail "UI tests failed (exit $code). HTML report: $WEB/playwright-report/index.html"
fi
