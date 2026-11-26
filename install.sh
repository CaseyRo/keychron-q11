#!/usr/bin/env bash
# keychron-q11 installer — run on the Mac the keyboard is attached to.
#
#   ./install.sh              Hammerspoon router (copy on select, the Herdr theme)
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

# Atrium publishes Now Playing now (NowPlaying.swift); the old agent would fight it for the entry.
old=~/Library/LaunchAgents/com.cdit.keychron-q11.nowplaying.plist
if [ -e "$old" ]; then
  launchctl bootout "gui/$(id -u)/com.cdit.keychron-q11.nowplaying" 2>/dev/null || true
  rm -f "$old"
  echo "✓ old now playing agent unloaded and removed"
fi
if [[ " $* " == *" --nowplaying "* ]]; then
  echo "--nowplaying is gone: Atrium publishes Now Playing now (~/dev/atrium, NowPlaying.swift)." >&2
fi

if [[ " $* " == *" --backlight "* ]]; then
  echo "--backlight is gone: Atrium sets the backlight now (~/dev/atrium, HouseLight.swift)." >&2
fi

open -a Hammerspoon
echo "→ grant Accessibility when prompted (look for the 'keychron-q11 armed' alert),"
echo "  then bind your keys once in Keychron Launcher: docs/launcher-keymap.md"
