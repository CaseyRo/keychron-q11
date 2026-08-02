#!/usr/bin/env bash
# keychron-q11 installer — run on the Mac the keyboard is attached to.
#
#   ./install.sh              Hammerspoon router (M-keys, encoders, Spotify)
#   ./install.sh --backlight  also install the day/night backlight agent
#
set -euo pipefail
cd "$(dirname "$0")"
# survive non-interactive shells (no brew/uv on PATH)
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

command -v brew >/dev/null || { echo "Homebrew required: https://brew.sh" >&2; exit 1; }
[ -d /Applications/Hammerspoon.app ] || brew install --cask hammerspoon

if [ -e ~/.hammerspoon ] && [ ! -L ~/.hammerspoon ]; then
  echo "~/.hammerspoon exists and is not a symlink — merge it manually, not clobbering." >&2
  exit 1
fi
ln -sfn "$PWD/hammerspoon" ~/.hammerspoon
echo "✓ hammerspoon config linked"

if [ "${1:-}" = "--backlight" ]; then
  command -v uv >/dev/null || { echo "uv required for the backlight agent: brew install uv" >&2; exit 1; }
  label=com.cdit.keychron-q11.backlight
  plist=~/Library/LaunchAgents/$label.plist
  sed -e "s|__UV__|$(command -v uv)|" -e "s|__REPO__|$PWD|" \
    "backlight/$label.plist" > "$plist"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
  echo "✓ backlight agent loaded (off 08:00 / on 18:00 — hours live in backlight/keylight.py)"
fi

open -a Hammerspoon
echo "→ grant Accessibility when prompted (look for the 'keychron-q11 armed' alert),"
echo "  then bind your keys once in Keychron Launcher: docs/launcher-keymap.md"
