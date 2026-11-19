# CLAUDE.md

Host side control for a Keychron Q11 Ultra 8K on macOS.

## Read the wiki before exploring source

Start at [docs/wiki/quickstart.md](docs/wiki/quickstart.md). It says which
document answers which kind of question, and
[docs/wiki/architecture.md](docs/wiki/architecture.md) holds the reasoning
behind the design. The code is commented for behavior, so read it for what
something does; read the wiki for why it is shaped that way.

Documentation follows [docs/wiki/DOCTRINE.md](docs/wiki/DOCTRINE.md). The
short version: the wiki never restates what the code or the README already
says, it stays flat, and every page is reachable from the Map in quickstart.

## Editing the router edits the live system

`~/.hammerspoon` is a symlink at `hammerspoon/`, so writing
`hammerspoon/init.lua` reloads the running router immediately. Two
consequences worth knowing before you edit:

- There is no deploy step, and no copy to keep in sync.
- The reload blocks the `hs` IPC port, so an `hs -c` call issued right after a
  write hangs or errors ("ipc port is no longer valid", "receive timeout").
  Measured 2026-11-18: 45 to 90 seconds, not a few. Wait a minute, and bound
  each call (`perl -e 'alarm 12; exec @ARGV' hs -c '...'`) rather than
  concluding something broke.
- Do not kill a hung `hs -c` and carry on: the dead client leaves the port
  broken until the next reload. `pkill -f '^hs -c'`, then
  `touch hammerspoon/init.lua` and wait again.
- Synthetic keystrokes (`hs.eventtap.keyStroke`) do not fire the router's own
  hotkeys. To exercise a binding, call its global instead: `q11Volume`,
  `q11MusicPress`, `q11ShowStages`, `q11ShowBezel`.

Check a live router with `hs -c`, which the config deliberately exposes:

```bash
hs -c 'return #hs.hotkey.getHotkeys()'   # expect 10, F14 and F15 absent
hs -c 'return hs.accessibilityState()'
hs -c 'q11PollRefresh()'                 # re-read the polling rate now
```

## Run the self checks before committing

```bash
uv run backlight/keylight.py selftest    # parsing, backlight, polling rules
uv run nowplaying/nowplaying.py selftest # Home Assistant answer parsing
hs -c 'return q11SwipeSelfTest()'        # swipe, tap and scroll swallow
hs -c 'return q11CycleSelfTest()'        # the encoder's split ring
```

There is no build. These are the gate.

## Do not probe the keyboard blindly

`docs/protocol.md` documents the HID command space, including which
subcommands are setters. `a7 0e` writes both polling rates at once, so a probe
of the form `a7 XX 00 00` can silently rewrite a real setting. Read a value
back before writing a neighbouring one, and never scan a range to see what
answers.

Reads can also fail for uninteresting reasons: an open Keychron Launcher tab
holds the same interface and steals replies, which is why reads retry.

## Layout

| Path | What it is |
| --- | --- |
| `hammerspoon/init.lua` | the router: keys, encoders, gestures, menubar |
| `backlight/keylight.py` | HID client: backlight and polling rate |
| `nowplaying/nowplaying.py` | launchd agent: office music as macOS Now Playing |
| `bin/q11-herdr` | runs on the remote host, not this one |
| `docs/` | protocol notes, keymap, wiki |
