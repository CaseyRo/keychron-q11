# keychron-q11

**Host-side control for the Keychron Q11 Ultra 8K on macOS** — turn the
split keyboard's macro column and two knobs into workspace keys,
context-aware encoders, and a backlight that follows the clock. Includes
the first published host-control protocol for Keychron's ZMK-based Ultra
series ([docs/protocol.md](docs/protocol.md)).

```
Q11 Ultra ──USB/2.4G──▶ Hammerspoon router ──▶ terminal / Spaces / Spotify
                        keylight.py (launchd) ──▶ backlight off by day, on by night
```

## What you get

| Control | Context | Action |
| --- | --- | --- |
| M1–M5 | anywhere | jump to terminal workspace 1–5 |
| left knob | terminal | walk splits, then cycle workspaces |
| left knob | elsewhere | macOS Spaces left/right |
| left knob press | terminal / elsewhere | zoom split / Mission Control |
| right knob (base) | anywhere | ↑ / ↓ / Enter — drive TUI menus (Claude Code, fzf, …) |
| right knob (scroll layer) | anywhere | scroll under pointer; press = jump to bottom |
| right knob (Spotify layer) | anywhere | Spotify app volume / play-pause — independent of system volume |
| backlight | 08:00–18:00 | off during the day, restored at night (launchd) |

Workspace navigation speaks to **herdr** (a terminal workspace manager)
over its socket API — optionally on a remote host via multiplexed ssh.
**No herdr? Everything degrades to plain `Cmd+N` / tab-cycling
keystrokes** — set `REMOTE = nil` in `hammerspoon/init.lua`.

## The protocol discovery

The Ultra 8K series runs Keychron's ZMK fork, so none of the QMK-era
host tools (VIA app, OpenRGB) apply — and no host-control tooling
existed. It turns out the firmware **implements the VIA v3 custom-values
protocol** on the `0xFF60` vendor HID collection: cmd `0x07/0x08/0x09`
(set/get/save), channel `0x03` = RGB matrix, value `0x02` = effect where
`0` means off. Works identically through the 2.4G receiver and wired.
Full notes, captured with a 30-line DevTools monkey-patch:
[docs/protocol.md](docs/protocol.md) · capture tool:
[backlight/sniff-helper.js](backlight/sniff-helper.js)

`backlight/keylight.py` uses it for scheduled day/night backlight — it
remembers your current effect before switching off and restores it after:

```bash
uv run backlight/keylight.py on|off|status
```

## Install

Requires macOS, [Homebrew](https://brew.sh), and for the backlight
[uv](https://docs.astral.sh/uv/) (`brew install uv`).

```bash
git clone https://github.com/CaseyRo/keychron-q11 ~/dev/keychron-q11
~/dev/keychron-q11/install.sh --backlight   # omit --backlight to skip the agent
```

Grant Hammerspoon **Accessibility** when prompted (the event tap needs
it), then bind your keys **once** in [Keychron Launcher](https://launcher.keychron.com)
following [docs/launcher-keymap.md](docs/launcher-keymap.md) — that file
also explains the two macOS traps below, learned the hard way.

## Two macOS traps (read before changing bindings)

1. **F21–F24 do not exist on macOS.** The virtual keycode table ends at
   F20; the OS silently drops those HID usages. Your effective bare-key
   budget is F13–F20 — extend with modifier combos (`LCAG(KC_F18)`).
2. **Bare F14/F15 are legacy display-brightness keys.** They never reach
   normal hotkey APIs; this config captures them with an event tap that
   swallows the keypress.

## Tuning

Everything is a constant near the top of a small file:

- `hammerspoon/init.lua` — terminal apps, herdr host (or `nil`), Spotify
  volume step
- `backlight/keylight.py` — day hours, fallback effect

## License

MIT — see [LICENSE](LICENSE).
