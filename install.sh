#!/usr/bin/env bash
# Run this ON THE MAC THE KEYBOARD IS ATTACHED TO (not cc1).
# Installs Hammerspoon, links the config, and checks the ssh path to cc1.
set -euo pipefail
cd "$(dirname "$0")"
# survive non-interactive ssh shells (no brew on PATH)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

[ -d /Applications/Hammerspoon.app ] || brew install --cask hammerspoon

if [ -e ~/.hammerspoon ] && [ ! -L ~/.hammerspoon ]; then
  echo "~/.hammerspoon exists and is not a symlink — merge it manually, not clobbering." >&2
  exit 1
fi
ln -sfn "$PWD/hammerspoon" ~/.hammerspoon
echo "config linked"

if ssh -o BatchMode=yes -o ConnectTimeout=3 cc1 dev/keychron-q11/bin/q11-herdr focus 1; then
  echo "cc1/herdr reachable"
else
  echo "WARNING: cc1 herdr helper not reachable — workspace keys will fall back to Cmd+N" >&2
fi

open -a Hammerspoon
echo "grant Accessibility when prompted; look for the 'keychron-q11 armed' alert"
