# One-time Keychron Launcher setup

Open https://launcher.keychron.com in a Chromium browser (Safari won't
work), connect the Q11 Ultra, and enter the bindings below — Launcher
accepts QMK-style keycodes in its custom-keycode field. This is the only
click-through step; everything downstream is code in this repo.

The keyboard sends **dumb signals**; `hammerspoon/init.lua` decides what
they mean per context.

## Read this first: two macOS traps

- **Never bind F21–F24.** macOS's virtual keycode table ends at F20 and
  the OS silently drops those HID usages — the key will simply do
  nothing, with no error anywhere. Your bare-key budget is F13–F20;
  extend it with modifier-wrapped keycodes like `LCAG(KC_F18)`
  (Ctrl+Alt+Cmd+F18).
- **Bare F14/F15 are macOS's legacy display-brightness keys.** This
  config still uses them — Hammerspoon captures them with an event tap
  and swallows the keypress — but any *other* tool binding them plainly
  will lose to the brightness handler.

  If M2/M3 ever start adjusting brightness again, the binding is fine —
  macOS disabled the tap underneath Hammerspoon. See trap 3 and
  Troubleshooting in the [README](../README.md); it self-heals within 30s.

## Base layer

| Physical control | Keycode  | Meaning (host-side)                                |
| ---------------- | -------- | -------------------------------------------------- |
| M1               | `KC_F13` | terminal workspace 1                                |
| M2               | `KC_F14` | terminal workspace 2 (event-tapped, see above)      |
| M3               | `KC_F15` | terminal workspace 3 (event-tapped, see above)      |
| M4               | `KC_F16` | terminal workspace 4                                |
| M5               | `KC_F17` | terminal workspace 5                                |
| Left knob ccw    | `KC_F18` | terminal: prev split/workspace · else Space left    |
| Left knob cw     | `KC_F19` | terminal: next split/workspace · else Space right   |
| Left knob press  | `KC_F20` | terminal: zoom split · else Mission Control         |
| Right knob ccw   | `KC_UP`  | pure keyboard — drive TUI menus                     |
| Right knob cw    | `KC_DOWN`| pure keyboard                                       |
| Right knob press | `KC_ENT` | pure keyboard — confirm                             |

## Scroll layer (e.g. your fn layer) — right knob

| Physical control | Keycode          | Meaning                         |
| ---------------- | ---------------- | ------------------------------- |
| Right knob ccw   | `KC_WH_U`        | scroll up under the pointer     |
| Right knob cw    | `KC_WH_D`        | scroll down under the pointer   |
| Right knob press | `LCAG(KC_F16)`   | jump to bottom (host-side)      |

Scrolling is **pure keyboard** — `KC_WH_U`/`KC_WH_D` need no host code at
all, so they keep working even if Hammerspoon is down. Host-side
`LCAG(KC_F14)`/`LCAG(KC_F15)` wheel emulation used to exist as a fallback
for Launchers without wheel keycodes; it was removed as dead weight. If
yours can't emit them, bind the F-keys and restore those two hotkeys from
git history. Jump-to-bottom has no wheel keycode, so it stays host-side.

## Spotify layer — right knob

| Physical control | Keycode          | Meaning              |
| ---------------- | ---------------- | -------------------- |
| Right knob ccw   | `LCAG(KC_F18)`   | Spotify volume up    |
| Right knob cw    | `LCAG(KC_F19)`   | Spotify volume down  |
| Right knob press | `LCAG(KC_F20)`   | Spotify play/pause   |

(`LCAG(...)` = Ctrl+Alt+Cmd; the nested form `C(A(G(KC_F18)))` is
equivalent if your Launcher rejects `LCAG`. Swap ccw/cw to taste — the
host side doesn't care which physical direction sends which code.)

## Layer mechanics

To *latch* a layer (rather than hold fn), bind `TG(n)` on a reachable
key — e.g. fn+M5 — put the layer's knob codes in layer *n*, leave every
other key there transparent (`KC_TRNS` / ▽), and put `TG(n)` in the same
spot inside layer *n* so pressing it again exits.

⚠️ On Keychron boards, one layer pair is the **Windows** base/fn set —
don't latch the Windows *base* layer, it swaps Cmd/Alt across the whole
board.
