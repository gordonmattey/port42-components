#!/bin/bash
# port42-companion — SessionStart hook
#
# Runs before the model acts on every session. Does two things:
#   1. Loads this session's relationship state into context (deterministic read).
#   2. Pins the resolved profile + bundled CLI into the session environment so
#      every later Bash tool call writes to the right profile and `port42-companion`
#      resolves to the bundled binary — no global install needed.
#
# Profile resolution (a profile is "Claude in a particular context"):
#   $PORT42_PROFILE if set  -> explicit override (e.g. a shared/"mixing" profile)
#   else cwd basename       -> automatic per-directory context
#   else "default"          -> legacy flat state dir
#
# The directory is the context signal, so launching Claude in a project dir gives
# that project its own companion state with no ceremony. We use the immediate
# directory name, NOT the git repo root: a monorepo (e.g. port42-growth holding
# companion + marketing + ...) must keep those contexts separate, and the git
# root would collapse them into one. Set PORT42_PROFILE to override (e.g. to
# deliberately share state across dirs, or to "mix").

set -e

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BIN="$ROOT/bin/port42-companion"

# SessionStart delivers a JSON payload on stdin including `cwd`. Read it when
# present (not a tty), fall back to $PWD.
CWD="$PWD"
if [ ! -t 0 ]; then
  INPUT="$(cat)"
  PARSED="$(printf '%s' "$INPUT" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("cwd",""))' 2>/dev/null || true)"
  [ -n "$PARSED" ] && CWD="$PARSED"
fi

# Resolve the profile.
if [ -n "${PORT42_PROFILE:-}" ]; then
  PROFILE="$PORT42_PROFILE"
else
  PROFILE="$(basename "$CWD" | tr -c 'A-Za-z0-9_-' '-' | sed 's/^-*//; s/-*$//')"
fi
PROFILE="${PROFILE:-default}"

# Pin to the model's subsequent Bash tool calls. Claude Code sources
# $CLAUDE_ENV_FILE before each Bash invocation.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=$ROOT/bin:$PATH"
    echo "export PORT42_PROFILE=$PROFILE"
  } >> "$CLAUDE_ENV_FILE"
fi

# Inject current state + the write protocol as session context (plain stdout).
echo "<port42-companion profile=\"$PROFILE\">"
PORT42_PROFILE="$PROFILE" "$BIN" all read
echo ""
cat "$ROOT/references/protocol-inject.md" 2>/dev/null || true
echo "</port42-companion>"
