# keychron-q11

**Host-side control for the Keychron Q11 Ultra 8K on macOS** — turn the
split keyboard's macro column and two knobs into workspace keys,
context-aware encoders, and a backlight that follows the house. Includes
a write-up of the host-control protocol for Keychron's ZMK-based Ultra
series, captured on the wire and checked against Keychron's own source
([docs/protocol.md](docs/protocol.md)).

```
Q11 Ultra ──USB/2.4G──▶ Atrium + Hammerspoon ─┬─▶ Spaces / splits / scroll    local
                                              ├─▶ ssh ─▶ herdr host    terminal only
                                              └─▶ Home Assistant       right knob only
                        Atrium ─────────────────▶ backlight follows HA house mode,
                                                  office music as macOS Now Playing
```

That split is the first thing to check when something feels broken: the
terminal path and the right knob are the only ones that leave the machine,
so if the left encoder works everywhere
*except* in the terminal, suspect ssh rather than the keyboard.

**Moving into Atrium.** Since 25 Nov 2026, M1–M5 and the left knob run in
[Atrium](../atrium) (`Sources/Atrium/Keys.swift`), a native app, instead of
Hammerspoon; the right knob and its bezel followed on 26 Nov 2026
(`OfficeMusic.swift`, `Bezel.swift`), so Hammerspoon holds no hotkeys any
more, and the polling-rate menubar the same day (`PollingMenu.swift`), the
backlight (`HouseLight.swift`), then Now Playing (`NowPlaying.swift`, replacing
`nowplaying.py` and its launchd agent), then copy on select in Herdr and its theme (`HerdrDesk.swift`,
replacing `bin/herdr-daylight`). The trackpad gestures and the stage picker
moved too, then were dropped on 26 Nov 2026 (COS-308). Hammerspoon keeps only the Storykeep meeting watcher until it retires (COS-311).

Install steps and the reasoning behind the design are in
[docs/wiki/quickstart.md](docs/wiki/quickstart.md).

## What you get

| Control | Context | Action |
| --- | --- | --- |
| M1–M5 | anywhere | jump to Herdr space 1–5 (herdr TUI workspace when only Warp runs). In Atrium |
| left knob | terminal | walk Herdr splits, on into the next space past the last one (wraps). In Atrium |
| left knob | elsewhere | the front app's tabs, ⌃Tab / ⌃⇧Tab. In Atrium |
| left knob press | terminal / elsewhere | zoom split / rcmd's Exposé (right ⌘ + .). In Atrium |
| right knob | anywhere | volume of whichever office player is playing, else the amplifier (Home Assistant; needs the [Launcher keymap](docs/launcher-keymap.md)). In Atrium |
| right knob press | anywhere | play/pause that player. In Atrium |
| right knob double press | anywhere | pause for three minutes, then resume; a single press resumes early. In Atrium |
| right knob feedback | anywhere | a bezel in the middle of the screen: the level as a speaker over sixteen blocks, play or pause with the title, the break. In Atrium |
| right knob (scroll layer) | anywhere | scroll under pointer; press = jump to bottom (in Atrium) |
| Now Playing | office music playing or paused | the office's title and artist are this Mac's Now Playing, so Top Shelf's music widget, Control Center and the play key show and play/pause it, artwork included. In Atrium |
| backlight | house mode `day`/`away` | off; restored on every other mode, the clock deciding when HA does not answer (1 min poll). In Atrium |
| Herdr theme | house mode `day` · `evening`/`night` | drenched moss · Cobalt (CDiT); other modes and no HA follow macOS, light → moss, dark → Cobalt (5 min + wake). In Atrium |
| mouse select in Herdr | Herdr | copies the selection, like Warp. In Atrium |
| bolt menubar item | anywhere | shows the 2.4G polling rate; its menu sets either transport, 125–8000 Hz, over IOKit HID. In Atrium |

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

Atrium uses it for the day/night backlight (`~/dev/atrium`,
`HouseLight.swift`, since 26 Nov 2026, COS-307). It remembers your current
effect before switching off and restores it after.

It polls every minute rather than switching at two fixed times, because a
keyboard that reconnects or re-pairs mid-window comes back with its own
saved effect — a schedule leaves that wrong until the next flip. A poll is a
no-op when the effect already matches, so polling costs nothing and never
re-writes the keyboard's flash.

### Home Assistant house mode (optional)

The backlight prefers an HA `input_select.house_mode` over the clock: modes
`day` and `away` go dark, every other mode (`morning`, `evening`, `night`,
`guest`, `custom`) lights up. Point it at your instance and stash a
long-lived token in the login keychain:

```bash
mkdir -p ~/.config && echo 'HA_URL=http://homeassistant.local:8123' > ~/.config/keychron-q11.env
security add-generic-password -s keychron-q11-ha -a "$USER" -w   # prompts, no shell history
```

No conf file or no token → it falls back to the clock (off from 8:00 to
18:00). Same for HA being down or off-network.

### Office music (optional)

The right knob and Now Playing in Atrium use the same URL and token, plus
two more lines in `~/.config/keychron-q11.env` naming your players:

```bash
OFFICE_PLAYERS=media_player.one,media_player.two   # whichever plays gets the knob
OFFICE_AMP=media_player.amplifier                  # volume target when none does
```

Without them the knob and Now Playing do nothing. While Atrium
holds Now Playing, the keyboard's play key pauses the office, not the Mac,
until something on the Mac starts playing.

## Install

Requires macOS and [Homebrew](https://brew.sh).

```bash
git clone https://github.com/CaseyRo/keychron-q11 ~/dev/keychron-q11
~/dev/keychron-q11/install.sh   # also unloads the old Now Playing agent, if it is there
```

Grant Hammerspoon **Accessibility** when prompted (the event tap needs
it), then bind your keys **once** in [Keychron Launcher](https://launcher.keychron.com)
following [docs/launcher-keymap.md](docs/launcher-keymap.md) — that file
also explains the macOS traps below, learned the hard way.

## Four macOS traps (read before changing bindings)

1. **F21–F24 do not exist on macOS.** The virtual keycode table ends at
   F20; the OS silently drops those HID usages. Your effective bare-key
   budget is F13–F20 — extend with modifier combos (`LCAG(KC_F18)`).
2. **Bare F14/F15 are legacy display-brightness keys.** They never reach
   normal hotkey APIs; Atrium captures them with an event tap that
   swallows the keypress (`Keys.swift` in `~/dev/atrium`).
3. **macOS disables event taps behind your back, and
   `hs.eventtap:isEnabled()` will not tell you.** That method reports
   Hammerspoon's own flag, not whether the OS still routes events to the
   tap. After a display sleep/wake or under load the tap goes dead while
   every diagnostic still looks healthy — enabled `true`, Accessibility
   granted, all hotkeys bound — and M2/M3 quietly revert to adjusting
   brightness. A watchdog that *checks* `isEnabled()` therefore never
   fires; Atrium re-arms its tap unconditionally every 30s instead, as
   Hammerspoon's `q11Health` did before the M-keys moved (COS-299).
4. **A USB device behind a Thunderbolt dock is invisible to
   `hs.usb.watcher`.** It delivered not one event for the 2.4G receiver
   across a full unplug and replug — no error in the console, and the
   callback's field name was right (`hs.usb.attachedDevices()` reports
   the same `vendorID` the callback tested). A dock hangs its ports off a
   different USB controller than a root port, and the IOKit notifications
   Hammerspoon subscribes to do not reach that far. Poll instead: the
   polling-rate menubar, in Atrium since 26 Nov 2026 (COS-306,
   `PollingMenu.swift`), asks IOKit for the keyboard's HID interface every
   30s and only talks to the keyboard when presence actually flips. Costs
   at-most-30s latency, which beats a mechanism that is silent.

## Troubleshooting

**M2/M3 changed the screen brightness instead of switching workspace.**
Trap 3. It self-heals within 30s. If it does not, check
`grep 'keys:' ~/Library/Logs/Atrium.log` for `no F14/F15 tap`, which
means Atrium lost Accessibility, and quitting and reopening Atrium arms
the tap again. Note that the knob still working does *not* mean the tap
is fine — the knob and M1/M4/M5 are registered hotkeys, a different
mechanism, so "knob fine, M2/M3 dead" points straight at the tap.

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

Atrium rebuilds the master every 30s, so this should no longer
bite: a dead master costs 30s of staleness instead of every terminal
keypress until something happens to warm it. Before that, the failure was
silent and looked exactly like broken hardware — the encoder still moved
Spaces, the M-keys still focused the terminal, and only the herdr half did
nothing. Measured on this link, a cold call took **6.9s against a 3s
`HERDR_TIMEOUT`**, so the press was killed and fell through to the local
fallback every single time. If terminal presses go dead again, read the
warm log — failed warms are the evidence a later check can no longer show.
The warm runs in Atrium now, which logs each failure:

```bash
grep 'keys:' ~/Library/Logs/Atrium.log   # failed warms, missing taps or hotkeys
```

Four settings make that hold, all in `sshOpts` in Atrium's `Keys.swift`: `ControlPersist=yes`
(a finite value lapses during any normal pause, and the next press pays a
cold handshake), `ControlPath=…%n` (`%n` is the name as typed — `%h` is
the *resolved* address, which Tailscale changes on a direct↔DERP switch,
silently orphaning the master), and `ServerAliveInterval`/`CountMax`
(`ConnectTimeout` bounds only the TCP connect, so a reachable-but-slow
host hangs straight past it) — the last two held **slack, at 10s/3**.
They were 2s/2, which tore the master down after four seconds of stall:
easy for a Tailscale reroute or a loaded remote, and every teardown put
the next terminal press on the ~2.6s cold path. They bound nothing a press
depends on, because `herdr()` already kills a stalled call after 3s
(`timeout` in `Keys.swift`); they only have to outlive a hiccup and still notice a
genuinely dead host before the next 30s warm tick.

**Nothing responds and you want to know why.** The config opens an
`hs.ipc` port, so you can interrogate the live router:

```bash
hs -c 'return #hs.hotkey.getHotkeys()'  # expect 0: every key is Atrium's now
hs -c 'return hs.accessibilityState()'
```

⚠️ That port accepts Lua from any local process. Fine on a personal
machine; drop the `require("hs.ipc")` line if that isn't your threat
model.

## Tuning

Everything is a constant near the top of a small file:

- `~/dev/atrium/Sources/Atrium/Keys.swift` — terminal apps, herdr host,
  and `timeout` (ceiling on one remote call before it falls back to a
  local keystroke)
- `~/dev/atrium/Sources/AtriumCore/Backlight.swift` — which house modes go
  dark, clock fallback hours, fallback effect

## License

MIT — see [LICENSE](LICENSE).
