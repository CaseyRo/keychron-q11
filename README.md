# keychron-q11

**Host-side control for the Keychron Q11 Ultra 8K on macOS** — turn the
split keyboard's macro column and two knobs into workspace keys,
context-aware encoders, and a backlight that follows the house. Includes
the first published host-control protocol for Keychron's ZMK-based Ultra
series ([docs/protocol.md](docs/protocol.md)).

```
Q11 Ultra ──USB/2.4G──▶ Hammerspoon router ─┬─▶ Spaces / Spotify / scroll   local
                                            └─▶ ssh ─▶ herdr host    terminal only
                        keylight.py (launchd) ──▶ backlight follows HA house mode
```

That split is the first thing to check when something feels broken: only
the terminal path leaves the machine, so if the encoder works everywhere
*except* in the terminal, suspect ssh rather than the keyboard.

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
| 3-finger swipe up | anywhere | cross-Space window Exposé (`rcmd expose`) |
| 3-finger swipe down | anywhere | show desktop |
| 4-finger tap | anywhere | pick a stage from a list of all of them |
| ⌘ + 4-finger swipe ←/→ | anywhere | place window left / right half |
| ⌘ + 4-finger swipe ↑/↓ | anywhere | maximize / centre window |
| backlight | house mode `day`/`away` | off; restored on every other mode (launchd, 10 min poll) |

Workspace navigation speaks to **herdr** (a terminal workspace manager)
over its socket API — optionally on a remote host via multiplexed ssh.
**No herdr? Everything degrades to plain `Cmd+N` / tab-cycling
keystrokes** — set `REMOTE = nil` in `hammerspoon/init.lua`.

## Trackpad gestures

The two swipes replace a BetterTouchTool preset, so BTT is no longer
needed for them. They are one row each in the `GESTURES` table in
`hammerspoon/init.lua` — add a direction or change the finger count
there.

`⌘` is a preference, not a workaround: every macOS three- and
four-finger swipe is switched off on this machine
(`TrackpadThreeFingerVertSwipeGesture = 0`), so nothing competes for the
bare swipe. A row's `cmd` field picks which one you want.

The layout keeps three fingers for *looking* at windows and four for
*moving* them:

| Fingers | Modifier | Territory |
| --- | --- | --- |
| 3 | none | Exposé / show desktop — the swipes BTT had here |
| 4, tapped | none | pick a stage |
| 4 | ⌘ | window placement (`rcmd window place`) |

A **stage** is a saved set of windows; with `spaceMode: single` it is what
this machine uses instead of Spaces, which is why there is only ever one
Space.

Tapping four fingers lists every stage and activates whichever you pick.
rcmd's own stage overview is bound to *holding* `caps` and has no CLI
verb — `rcmd osd` only drives the search surfaces (`app`, `window`,
`hide`) — and a hold-to-show OSD does not map onto a momentary tap in any
case. So the list is built from `rcmd stage list --json` and shown in an
`hs.chooser`, which types-to-filter and picks rather than only displays.
A physical four-finger *click* registers as a tap too: the fingers are
down, still, and briefly.

A tap is recognised as the absence of a swipe — under `TAP_TRAVEL` of
movement, released inside `TAP_HOLD`. `TAP_TRAVEL` sits well below
`SWIPE_MIN`, and the gap between them is a deliberate dead zone so a
swipe that dies early resolves to nothing rather than to a tap.

Two things are deliberately *not* bound:

- **Closing a stage.** `stageCloseAction` is `close`, so `rcmd stage
  close` shuts the real windows — including any terminal running an
  agent. Switching stages is reversible, closing them is not, and no
  stray gesture should be able to do it.
- **Saving a stage, and re-applying its placements.** Both are
  keyboard-only (`stageAssignKey` / `stageRepositionKey` under `caps`)
  with no CLI equivalent, so a gesture cannot reach them at all.

A swipe fires **the moment it crosses `SWIPE_MIN`**, not when the fingers
lift — waiting for release makes an already-recognisable gesture feel
like it lagged. One swipe fires one action.

The fingers driving a swipe drive a **scroll** as well, on a separate
event stream, so the window underneath scrolls for as long as
recognition takes unless that stream is swallowed too. Both streams are
suppressed only while a finger count *and* modifier already bound in
`GESTURES` is in flight, so ordinary two-finger scrolling is never
touched.

Two more things are worth knowing before tuning this on another trackpad.
macOS interleaves gesture events that carry **no touches at all** between
the ones carrying fingers, so treating a zero-touch event as "fingers
lifted" shatters one swipe into dozens of fragments — the gesture ends on
a quiet timer (`SWIPE_IDLE`) instead. And travel distance varies by
device, so `SWIPE_MIN` and `TAP_TRAVEL` need measuring rather than
guessing:

```bash
hs -c "q11SwipeDebug = true"   # gesture a few times, then:
hs -c "q11SwipeReport()"
# fingers=3 dx=+0.0050 dy=+0.1840 held=0.18s cmd=false -> swipe
# fingers=4 dx=+0.0004 dy=-0.0011 held=0.09s cmd=false -> tap
# fingers=3 dx=+0.0030 dy=+0.0410 held=0.22s cmd=false -> nothing
```

Set `SWIPE_MIN` below the `dy` of a lazy swipe and above the largest
stray one. The `-> nothing` rows are the ones that landed in the dead
zone between `TAP_TRAVEL` and `SWIPE_MIN`; a gesture you meant showing up
there is the signal to move one of the two. `hs -c "q11SwipeSelfTest()"`
checks the direction classifier and the tap thresholds without needing a
trackpad.

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

`backlight/keylight.py` uses it for the day/night backlight — it
remembers your current effect before switching off and restores it after:

```bash
uv run backlight/keylight.py on|off|auto|status|selftest
```

The agent runs `auto` on a 10-minute poll rather than at two fixed times,
because a keyboard that reconnects or re-pairs mid-window comes back with
its own saved effect — a schedule leaves that wrong until the next flip.
`auto` is a no-op when the effect already matches, so polling costs nothing
and never re-writes the keyboard's flash.

### Home Assistant house mode (optional)

`auto` prefers an HA `input_select.house_mode` over the clock: modes `day`
and `away` go dark, every other mode (`morning`, `evening`, `night`,
`guest`, `custom`) lights up. Point it at your instance and stash a
long-lived token in the login keychain:

```bash
mkdir -p ~/.config && echo 'HA_URL=http://homeassistant.local:8123' > ~/.config/keychron-q11.env
security add-generic-password -s keychron-q11-ha -a "$USER" -w   # prompts, no shell history
```

No conf file or no token → it silently falls back to the `DAY_STARTS`/
`DAY_ENDS` clock, same as before. Same for HA being down or off-network.

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
also explains the macOS traps below, learned the hard way.

## Three macOS traps (read before changing bindings)

1. **F21–F24 do not exist on macOS.** The virtual keycode table ends at
   F20; the OS silently drops those HID usages. Your effective bare-key
   budget is F13–F20 — extend with modifier combos (`LCAG(KC_F18)`).
2. **Bare F14/F15 are legacy display-brightness keys.** They never reach
   normal hotkey APIs; this config captures them with an event tap that
   swallows the keypress.
3. **macOS disables event taps behind your back, and
   `hs.eventtap:isEnabled()` will not tell you.** That method reports
   Hammerspoon's own flag, not whether the OS still routes events to the
   tap. After a display sleep/wake or under load the tap goes dead while
   every diagnostic still looks healthy — enabled `true`, Accessibility
   granted, all hotkeys bound — and M2/M3 quietly revert to adjusting
   brightness. A watchdog that *checks* `isEnabled()` therefore never
   fires; `healthTick` re-arms unconditionally every 30s instead.

## Troubleshooting

**M2/M3 changed the screen brightness instead of switching workspace.**
Trap 3. It self-heals within 30s. To confirm rather than wait:
`hs -c 'q11MTap:stop():start()'`. Note that the encoder still working
does *not* mean the tap is fine — encoders go through `hs.hotkey.bind`,
a different mechanism, so "encoder fine, M-keys dead" points straight at
the tap.

**Keys respond slowly, or seem to do nothing, only inside the terminal.**
Every M-key and left-encoder action in a terminal goes over ssh to the
herdr host; everything else is local. So terminal-only slowness means the
ssh path, not the keyboard. Measured on a Tailscale link:

| path | cost |
| --- | --- |
| through a live ControlMaster | ~85ms |
| re-establishing the master | ~2.6s |
| remote host had slept | ~8.5s, presses stacking up |

Only the first is usable, so **keeping the master alive is the feature,
not an optimisation.** Check it at the moment of failure — a warm test
always passes and hides the bug:

```bash
ssh -O check -o "ControlPath=/tmp/keychron-q11-%r@%n" <host>
```

Three settings make that hold, all in `SSH_OPTS`: `ControlPersist=yes`
(a finite value lapses during any normal pause, and the next press pays a
cold handshake), `ControlPath=…%n` (`%n` is the name as typed — `%h` is
the *resolved* address, which Tailscale changes on a direct↔DERP switch,
silently orphaning the master), and `ServerAliveInterval`/`CountMax`
(`ConnectTimeout` bounds only the TCP connect, so a reachable-but-slow
host hangs straight past it).

**Nothing responds and you want to know why.** The config opens an
`hs.ipc` port, so you can interrogate the live router:

```bash
hs -c 'return q11MTap:isEnabled()'      # lies — see trap 3
hs -c 'return #hs.hotkey.getHotkeys()'  # expect 10 — F14/F15 must NOT appear
hs -c 'return hs.accessibilityState()'
```

⚠️ That port accepts Lua from any local process. Fine on a personal
machine; drop the `require("hs.ipc")` line if that isn't your threat
model.

## Tuning

Everything is a constant near the top of a small file:

- `hammerspoon/init.lua` — terminal apps, herdr host (or `nil`), Spotify
  volume step, `HERDR_TIMEOUT` (ceiling on one remote call before it
  falls back to a local keystroke)
- `backlight/keylight.py` — which house modes go dark, clock fallback hours,
  fallback effect

## License

MIT — see [LICENSE](LICENSE).
