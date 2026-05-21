#!/usr/bin/env bash
# check.sh — is @opensubagents/ts-bootstrap-mcp reachable from this sandbox?
#
# Prints exactly one line:
#   OK ts-bootstrap-mcp reachable via <method>
#   MISSING ts-bootstrap-mcp not registered, not on PATH, and no local clone
#
# Exit codes:
#   0  reachable
#   1  missing
#
# Idempotent. Read-only. No deps beyond bash + standard POSIX tools.

set -u

# Method 1: claude CLI knows about it
if command -v claude >/dev/null 2>&1; then
  if claude mcp list 2>/dev/null | grep -qiE '(^|[[:space:]])ts-bootstrap([[:space:]]|$)'; then
    echo "OK ts-bootstrap-mcp reachable via claude-mcp-list"
    exit 0
  fi
fi

# Method 2: binary on PATH (e.g. installed globally via npm -g)
if command -v ts-bootstrap-mcp >/dev/null 2>&1; then
  echo "OK ts-bootstrap-mcp reachable via PATH ($(command -v ts-bootstrap-mcp))"
  exit 0
fi

# Method 3: local clone with built dist/
for candidate in \
  /tmp/ts-bootstrap-mcp \
  "${HOME:-/root}/ts-bootstrap-mcp" \
  ./ts-bootstrap-mcp; do
  if [ -f "$candidate/dist/index.js" ]; then
    echo "OK ts-bootstrap-mcp reachable via local clone at $candidate"
    exit 0
  fi
done

echo "MISSING ts-bootstrap-mcp not registered, not on PATH, and no local clone — run scripts/install.sh"
exit 1
