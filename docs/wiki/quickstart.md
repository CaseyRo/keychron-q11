# keychron-q11

Host side control for a Keychron Q11 Ultra 8K on macOS. The keyboard sends
plain F13 to F20 signals, bound once in Keychron Launcher. On the Mac,
Atrium (`~/dev/atrium`) handles M1–M5, both knobs, the polling rate, the
backlight following the house, the office music as Now Playing, the trackpad gestures, copy on select in Herdr and its theme. Hammerspoon keeps only the Storykeep meeting watcher until it retires (COS-311).

## Shortest path

1. `./install.sh`. It symlinks `~/.hammerspoon` at this repo and opens Hammerspoon.
2. Grant Accessibility when prompted.
3. Bind the keys once in Keychron Launcher, following
   [launcher-keymap](../launcher-keymap.md).
4. For M1–M5 and the left knob, build and start Atrium:
   `~/dev/atrium/scripts/build.sh` (its README, Building), then grant it
   Accessibility.

Step 3 is the only click through in the project. Everything after it is code
here, and editing `hammerspoon/init.lua` reloads the live router, because
`~/.hammerspoon` is a symlink at this directory rather than a copy.

## Where each kind of question is answered

Behavior lives in the code, which is commented for it. This wiki holds the
reasoning that does not fit beside a line of code, and points at the canonical
home for everything else.

| Question | Answered in |
| --- | --- |
| What each key, knob and gesture does | control table in the [README](../../README.md) |
| Which keycode to bind on the board | [launcher-keymap](../launcher-keymap.md) |
| Why a binding silently does nothing | four macOS traps in the [README](../../README.md) |
| It worked yesterday and not today | troubleshooting in the [README](../../README.md) |
| How the host talks to the keyboard over HID | [protocol](../protocol.md) |
| Why the pieces are shaped the way they are | [architecture](architecture.md) |
| What a specific binding actually does | Atrium's `Sources/Atrium/Keys.swift` for every key and knob, `PollingMenu.swift` for the polling rate, `Trackpad.swift` and `AtriumCore/Gestures.swift` for gestures |

## Two things worth knowing before you debug

Two paths leave this machine: workspace navigation and the right knob. A
control that works everywhere except inside the terminal is an ssh problem,
and a dead right knob is a Home Assistant problem; neither is a keyboard
problem. See [architecture](architecture.md).

Most bindings are registered hotkeys, but M2 and M3 go through Atrium's event
tap, because macOS claims those two keys first. The two mechanisms fail
independently, so "encoder fine, M keys dead" is a real and useful signal.

## Map

- [quickstart](quickstart.md): this page. Install, and which document answers
  which kind of question.
- [architecture](architecture.md): the four paths a keypress can take, the
  design calls behind them, what is left unsolved, and how this stands
  against other Q11 Ultra setups.
- [DOCTRINE](DOCTRINE.md): the structure rules every change to this wiki
  follows, including what a compiler run may and may not generate.
