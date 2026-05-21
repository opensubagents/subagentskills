#!/usr/bin/env bash
# install.sh — install @opensubagents/ts-bootstrap-mcp in this sandbox.
#
# Tries three methods in order, stops on the first success:
#   1. claude CLI:        claude mcp add ts-bootstrap -- npx -y github:opensubagents/ts-bootstrap-mcp
#   2. global npm:        npm install -g github:opensubagents/ts-bootstrap-mcp
#   3. local clone:       git clone + npm install + npm run build into /tmp/ts-bootstrap-mcp
#
# Idempotent: re-running after a successful install is a no-op (each method's
# preflight detects already-installed state and skips).
#
# Exit codes:
#   0  installed (or already installed) via at least one method
#   1  all methods failed; sandbox cannot host the plugin

set -u

REPO_URL="github:opensubagents/ts-bootstrap-mcp"
GIT_URL="https://github.com/opensubagents/ts-bootstrap-mcp.git"
LOCAL_CLONE="/tmp/ts-bootstrap-mcp"

log()  { printf "[install.sh] %s\n" "$*" >&2; }
# shellcheck disable=SC2317
ok()   { printf "OK  %s\n" "$*"; }
# shellcheck disable=SC2317
fail() { printf "FAIL  %s\n" "$*" >&2; }

# NOTE on SC2317: every try_* function below is invoked indirectly via the
# `for method in try_*; do "$method"; done` loop in main(). Shellcheck cannot
# see through that, so we silence SC2317 (unreachable) per function.

# ---- Method 1: claude CLI ----
# shellcheck disable=SC2317
try_claude_mcp_add() {
  if ! command -v claude >/dev/null 2>&1; then
    log "method 1 (claude mcp add): claude CLI not on PATH, skipping"
    return 1
  fi
  if claude mcp list 2>/dev/null | grep -qiE '(^|[[:space:]])ts-bootstrap([[:space:]]|$)'; then
    log "method 1: already registered with claude CLI, nothing to do"
    ok "already registered via claude mcp"
    return 0
  fi
  log "method 1: registering with claude CLI..."
  if claude mcp add ts-bootstrap -- npx -y "$REPO_URL" 2>&1; then
    ok "installed via claude mcp add"
    return 0
  fi
  fail "method 1: claude mcp add returned non-zero"
  return 1
}

# ---- Method 2: global npm install ----
# shellcheck disable=SC2317
try_npm_install_global() {
  if ! command -v npm >/dev/null 2>&1; then
    log "method 2 (npm -g): npm not on PATH, skipping"
    return 1
  fi
  if command -v ts-bootstrap-mcp >/dev/null 2>&1; then
    log "method 2: already on PATH ($(command -v ts-bootstrap-mcp)), nothing to do"
    ok "already installed via npm -g"
    return 0
  fi
  # Check the global bin dir is writable. Most sandboxes set npm prefix to
  # ~/.npm-global or similar; the typical /usr/lib/node_modules will not be.
  local prefix
  prefix="$(npm config get prefix 2>/dev/null || true)"
  local bin_dir="${prefix:-/usr/local}/bin"
  if [ ! -w "$bin_dir" ] && [ ! -w "${prefix:-/usr/local}" ]; then
    log "method 2: global bin dir ($bin_dir) not writable, skipping"
    return 1
  fi
  log "method 2: npm install -g $REPO_URL..."
  if npm install -g "$REPO_URL" --no-audit --no-fund 2>&1; then
    ok "installed via npm -g"
    return 0
  fi
  fail "method 2: npm install -g returned non-zero"
  return 1
}

# ---- Method 3: local clone + build ----
# shellcheck disable=SC2317
try_local_clone() {
  if [ -f "$LOCAL_CLONE/dist/index.js" ]; then
    log "method 3: already cloned + built at $LOCAL_CLONE, nothing to do"
    ok "already cloned at $LOCAL_CLONE"
    return 0
  fi
  if ! command -v git >/dev/null 2>&1; then
    log "method 3 (clone): git not on PATH, skipping"
    return 1
  fi
  if ! command -v npm >/dev/null 2>&1; then
    log "method 3 (clone): npm not on PATH, skipping"
    return 1
  fi

  if [ -d "$LOCAL_CLONE/.git" ]; then
    log "method 3: refreshing existing clone at $LOCAL_CLONE..."
    if ! (cd "$LOCAL_CLONE" && git fetch origin main && git reset --hard origin/main); then
      fail "method 3: git fetch/reset failed"
      return 1
    fi
  else
    log "method 3: cloning $GIT_URL to $LOCAL_CLONE..."
    rm -rf "$LOCAL_CLONE"
    if ! git clone --depth 1 "$GIT_URL" "$LOCAL_CLONE" 2>&1; then
      fail "method 3: git clone failed"
      return 1
    fi
  fi

  log "method 3: npm install + npm run build in $LOCAL_CLONE..."
  if ! (cd "$LOCAL_CLONE" && npm install --no-audit --no-fund --prefer-offline && npm run build) 2>&1; then
    fail "method 3: npm install or build failed"
    return 1
  fi
  ok "installed via local clone at $LOCAL_CLONE"
  log "to register with Claude Code: claude mcp add ts-bootstrap -- node $LOCAL_CLONE/dist/index.js"
  return 0
}

# ---- main ----
main() {
  for method in try_claude_mcp_add try_npm_install_global try_local_clone; do
    if "$method"; then
      log "next: run scripts/check.sh to confirm"
      exit 0
    fi
  done
  fail "all three install methods failed; this sandbox cannot host the plugin"
  exit 1
}

main "$@"
