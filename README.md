# keychron-q11

*Host-side daemon & routing for the Keychron Q11 Ultra 8K (split, M1–M5
macro column, two knobs): workspace keys, context-aware encoders, and
scheduled backlight.*

The keyboard is configured **once** in [Keychron Launcher](https://launcher.keychron.com)
to send dumb signal keys (F13–F23, see `docs/launcher-keymap.md`). A single
Hammerspoon config then routes them by context:

| Signal        | Context      | Action                                          |
| ------------- | ------------ | ----------------------------------------------- |
| M1–M5         | anywhere     | focus Warp + herdr workspace 1–5 (fallback: Warp tab N) |
| left knob     | Warp         | walk herdr splits; at the edge, next/prev workspace |
| left knob     | elsewhere    | macOS Spaces left/right                         |
| left knob ⏷   | Warp         | zoom the focused split                          |
| left knob ⏷   | elsewhere    | Mission Control                                 |
| right knob    | base layer   | system volume (bound on-keyboard, no host code) |
| fn+right knob | anywhere     | Spotify app volume / play-pause                 |

Gotcha worth knowing: bare F14/F15 are macOS's legacy display-brightness
keys and never reach `hs.hotkey` — M2/M3 are captured by an event tap that
swallows the keypress instead.

## Topology — two Macs

The keyboard (and Spotify, and the Launcher/WebHID session) is attached to
the **local Mac**; the herdr server runs on **cc1**. Hammerspoon therefore
runs locally and reaches herdr via `ssh cc1 dev/keychron-q11/bin/q11-herdr`
(multiplexed with ControlPersist, so encoder detents don't pay a handshake).
No fake keystrokes into the terminal — real socket API on cc1.

```
Q11 Ultra ──USB/2.4G──▶ local Mac: Hammerspoon router ──ssh──▶ cc1: herdr
                                   └─ Spotify / Spaces / keylight.py locally
```

## Install (on the local Mac, not cc1)

```bash
git clone <this repo> ~/dev/keychron-q11 && ~/dev/keychron-q11/install.sh
```

Then do the one-time Launcher keymap (`docs/launcher-keymap.md`).
Requires non-interactive `ssh cc1` (BatchMode) to work — 1Password agent
prompts will make the workspace keys fall back to Cmd+N until unlocked.

## Backlight day/night (`backlight/`) — working

Despite running ZMK, the Ultra series speaks the **VIA v3 custom-values
protocol** on HID usage page `0xFF60` — reverse-engineered 2026-08-02 with
`backlight/sniff-helper.js`, documented in `docs/protocol.md` (no published
prior art existed). `keylight.py` (uv script, hidapi) sets the RGB-matrix
effect: `0` = off; "on" restores the last-seen effect from
`~/.local/state/keychron-q11-effect`.

Deployed as launchd agent `com.cdit.keychron-q11.backlight`: off 08:00,
on 18:00, `auto` self-corrects on boot/wake. Manual override any time:

```bash
uv run backlight/keylight.py on|off|status
```

Gotcha: an open Launcher tab shares the HID interface and races read-backs.

## Later, when it has proven itself

- zsh-setup module to clone + symlink this on new Mac hosts (the wsx pattern)
- capture the sniffed protocol notes in `docs/` — it's unpublished territory
