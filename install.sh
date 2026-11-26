#!/usr/bin/env bash
# keychron-q11 installer — run on the Mac the keyboard is attached to.
#
#   ./install.sh              Hammerspoon router (M-keys, encoders, Spotify)
#   ./install.sh --nowplaying also publish the office's music as Now Playing
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

# Render a launchd template from <dir>/<label>.plist and (re)load it.
agent() {
  command -v uv >/dev/null || { echo "uv required for $2: brew install uv" >&2; exit 1; }
  local label=com.cdit.keychron-q11.$1 plist=~/Library/LaunchAgents/com.cdit.keychron-q11.$1.plist
  sed -e "s|__UV__|$(command -v uv)|" -e "s|__REPO__|$PWD|" "$1/$label.plist" > "$plist"
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
}

if [[ " $* " == *" --nowplaying "* ]]; then
  agent nowplaying "the Now Playing agent"
  echo "✓ now playing agent loaded (needs HA_URL and OFFICE_PLAYERS in"
  echo "  ~/.config/keychron-q11.env — see README)"
fi

if [[ " $* " == *" --backlight "* ]]; then
  echo "--backlight is gone: Atrium sets the backlight now (~/dev/atrium, HouseLight.swift)." >&2
fi

open -a Hammerspoon
echo "→ grant Accessibility when prompted (look for the 'keychron-q11 armed' alert),"
echo "  then bind your keys once in Keychron Launcher: docs/launcher-keymap.md"
