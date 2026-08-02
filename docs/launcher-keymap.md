# One-time Keychron Launcher setup

Open https://launcher.keychron.com in a Chromium browser (Safari won't work),
connect the Q11 Ultra, and bind the signal keys below. This is the only
click-through step — everything downstream is code in this repo.

The keyboard sends **dumb signals** (F13–F23); `hammerspoon/init.lua` decides
what they mean per context. If Launcher's key picker doesn't offer F13+ for
this board, fall back to Hyper combos (⌘⌃⌥⇧ + 1…5 etc.) and adjust the binds
in `init.lua` to match.

## Base layer

| Physical control      | Bind to | Meaning (host-side)                                   |
| --------------------- | ------- | ----------------------------------------------------- |
| M1                    | F13     | Focus Warp + herdr workspace 1 (fallback: Warp tab 1) |
| M2                    | F14     | … workspace 2                                         |
| M3                    | F15     | … workspace 3                                         |
| M4                    | F16     | … workspace 4                                         |
| M5                    | F17     | … workspace 5                                         |
| Left knob ccw         | F18     | Warp: prev herdr workspace · elsewhere: Space left    |
| Left knob cw          | F19     | Warp: next herdr workspace · elsewhere: Space right   |
| Left knob press       | F20     | Mission Control                                       |
| Right knob ccw/cw     | (keep)  | System volume — leave the factory media binding       |
| Right knob press      | (keep)  | Mute — leave factory binding                          |

## fn layer

**Not F21–F24** — macOS has no virtual keycodes above F20 and silently
drops those HID usages, so bindings there never reach the host. With
F13–F20 all spent, the fn layer reuses F18–F20 behind a hyper modifier:

| Physical control  | Bind to        | Meaning (host-side)  |
| ----------------- | -------------- | -------------------- |
| Right knob ccw    | ⌘⌥⌃ + F18      | Spotify volume down  |
| Right knob cw     | ⌘⌥⌃ + F19      | Spotify volume up    |
| Right knob press  | ⌘⌥⌃ + F20      | Spotify play/pause   |

Optional while the backlight automation isn't built yet: bind an RGB toggle
somewhere reachable (e.g. fn+M1) for the manual day/night flip.
