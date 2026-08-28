# keychron-q11

Host side control for a Keychron Q11 Ultra 8K on macOS. The keyboard sends
plain F13 to F20 signals, bound once in Keychron Launcher. A Hammerspoon
router on the Mac decides what those signals mean per context, and a launchd
agent keeps the backlight following the house.

## Shortest path

1. `./install.sh`, adding `--backlight` if you also want the lighting agent.
   It symlinks `~/.hammerspoon` at this repo and opens Hammerspoon.
2. Grant Accessibility when prompted. The alert "keychron-q11 armed" means the
   router loaded.
3. Bind the keys once in Keychron Launcher, following
   [launcher-keymap](../launcher-keymap.md).

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
| What a specific binding actually does | `hammerspoon/init.lua` |

## Two things worth knowing before you debug

Only the workspace navigation path leaves this machine. A control that works
everywhere except inside the terminal is an ssh problem, not a keyboard
problem. See [architecture](architecture.md).

Most bindings go through `hs.hotkey.bind`, but M2 and M3 go through an event
tap, because macOS claims those two keys first. The two mechanisms fail
independently, so "encoder fine, M keys dead" is a real and useful signal.

## Map

- [quickstart](quickstart.md): this page. Install, and which document answers
  which kind of question.
- [architecture](architecture.md): the three paths a keypress can take, and
  the design calls behind them.
- [DOCTRINE](DOCTRINE.md): the structure rules every change to this wiki
  follows, including what a compiler run may and may not generate.
