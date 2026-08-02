# steuerhorn

*The pilot's yoke for the desk cockpit — host-side brains for the Keychron
Q11 Ultra 8K (split, M1–M5 macro column, two knobs).*

The keyboard is configured **once** in [Keychron Launcher](https://launcher.keychron.com)
to send dumb signal keys (F13–F23, see `docs/launcher-keymap.md`). A single
Hammerspoon config then routes them by context:

| Signal        | Context      | Action                                          |
| ------------- | ------------ | ----------------------------------------------- |
| M1–M5         | anywhere     | focus Warp + herdr workspace 1–5 (fallback: Warp tab N) |
| left knob     | Warp         | prev/next herdr workspace                       |
| left knob     | elsewhere    | macOS Spaces left/right                         |
| left knob ⏷   | anywhere     | Mission Control                                 |
| right knob    | base layer   | system volume (bound on-keyboard, no host code) |
| fn+right knob | anywhere     | Spotify app volume / play-pause                 |

## Topology — two Macs

The keyboard (and Spotify, and the Launcher/WebHID session) is attached to
the **local Mac**; the herdr server runs on **cc1**. Hammerspoon therefore
runs locally and reaches herdr via `ssh cc1 dev/steuerhorn/bin/steuerhorn-herdr`
(multiplexed with ControlPersist, so encoder detents don't pay a handshake).
No fake keystrokes into the terminal — real socket API on cc1.

```
Q11 Ultra ──USB/2.4G──▶ local Mac: Hammerspoon router ──ssh──▶ cc1: herdr
                                   └─ Spotify / Spaces / keylight.py locally
```

## Install (on the local Mac, not cc1)

```bash
git clone <this repo> ~/dev/steuerhorn && ~/dev/steuerhorn/install.sh
```

Then do the one-time Launcher keymap (`docs/launcher-keymap.md`).
Requires non-interactive `ssh cc1` (BatchMode) to work — 1Password agent
prompts will make the workspace keys fall back to Cmd+N until unlocked.

## Backlight day/night (`backlight/`) — in progress

The Ultra series runs Keychron's ZMK fork with a **proprietary HID protocol**
(no VIA/QMK raw HID — none of the QMK-era tooling applies, and no host-control
prior art exists as of 2026-08). Plan:

1. Open Launcher with DevTools, paste `backlight/sniff-helper.js`, toggle the
   backlight in the UI, and copy the logged report bytes.
2. Fill `PID` and `REPORTS` in `backlight/keylight.py`.
3. `cp backlight/com.cdit.steuerhorn.backlight.plist ~/Library/LaunchAgents/`
   and `launchctl load` it — backlight off 08:00, on 18:00, self-correcting
   on boot/wake via `auto`.

Until then: manual RGB-toggle key bound on the keyboard.

## Later, when it has proven itself

- zsh-setup module to clone + symlink this on new Mac hosts (the wsx pattern)
- capture the sniffed protocol notes in `docs/` — it's unpublished territory
