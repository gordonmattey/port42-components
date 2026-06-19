#!/bin/bash
# Install port42-companion
# Usage:
#   ./scripts/install.sh                              — install globally
#   ./scripts/install.sh --config-dir ~/.claude-nexus — install to alternate Claude config dir
#   ./scripts/install.sh --update                     — replace existing protocol in CLAUDE.md
#   CLAUDE_CONFIG_DIR=~/.claude-nexus ./scripts/install.sh

set -e

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_SRC="$SKILL_DIR/bin/port42-companion"
PROTOCOL="$SKILL_DIR/protocol.md"

CONFIG_DIR_OVERRIDE=""
UPDATE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-dir) CONFIG_DIR_OVERRIDE="$2"; shift 2 ;;
    --update)     UPDATE=true; shift ;;
    *) shift ;;
  esac
done

CLAUDE_CONFIG_DIR="${CONFIG_DIR_OVERRIDE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
CLAUDE_MD="$CLAUDE_CONFIG_DIR/CLAUDE.md"
BIN_DIR="$HOME/.local/bin"

# Install CLI
mkdir -p "$BIN_DIR"
cp "$BIN_SRC" "$BIN_DIR/port42-companion"
chmod +x "$BIN_DIR/port42-companion"
echo "✓ port42-companion installed at $BIN_DIR/port42-companion"

# Check PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "  ⚠ $BIN_DIR is not in your PATH"
  echo "  Add to your shell profile: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# Inject protocol into CLAUDE.md
touch "$CLAUDE_MD"

if grep -q "<!-- port42-companion:start -->" "$CLAUDE_MD" 2>/dev/null; then
  if [ "$UPDATE" = true ]; then
    sed -i '' '/<!-- port42-companion:start -->/,/<!-- port42-companion:end -->/d' "$CLAUDE_MD"
    echo "updating protocol in $CLAUDE_MD"
  else
    echo "protocol already installed in $CLAUDE_MD (use --update to replace)"
    exit 0
  fi
fi

{
  echo ""
  echo "<!-- port42-companion:start -->"
  cat "$PROTOCOL"
  echo "<!-- port42-companion:end -->"
} >> "$CLAUDE_MD"

echo "✓ protocol injected into $CLAUDE_MD"
