#!/usr/bin/env bash
set -euo pipefail

# gwt installer — downloads gwt.sh and adds a source line to your shell rc.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/RKrogh/gwt/main/install.sh | bash
#   bash install.sh                # from a local clone
#   bash install.sh --update       # re-download latest version

GWT_REPO="https://raw.githubusercontent.com/RKrogh/gwt/master"
GWT_DIR="${GWT_HOME:-$HOME/.local/share/gwt}"
GWT_SH="$GWT_DIR/gwt.sh"

# Detect shell rc file
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    RC_FILE="$HOME/.zshrc"
else
    RC_FILE="$HOME/.bashrc"
fi

mkdir -p "$GWT_DIR"

# Download or copy gwt.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$SCRIPT_DIR/gwt.sh" ] && [ "${1:-}" != "--update" ]; then
    cp "$SCRIPT_DIR/gwt.sh" "$GWT_SH"
    echo "Copied gwt.sh from local clone"
else
    curl -fsSL "$GWT_REPO/gwt.sh" -o "$GWT_SH"
    echo "Downloaded latest gwt.sh"
fi

# Add source line to shell rc if not present
SOURCE_LINE=". \"$GWT_SH\""
if ! grep -qF "$GWT_SH" "$RC_FILE" 2>/dev/null; then
    printf '\n# gwt — git worktree manager\n%s\n' "$SOURCE_LINE" >> "$RC_FILE"
    echo "Added source line to $RC_FILE"
else
    echo "Source line already in $RC_FILE"
fi

echo "gwt installed — restart your shell or run: source $RC_FILE"
