# Architecture

Why the pieces are shaped this way. Behavior itself is in the code and in the
[README](../../README.md) control table; this page is the reasoning behind the
shape.

## Four paths, and why the split is a diagnostic

A keypress takes one of four routes:

- **Local.** Tabs, rcmd's Exposé, scrolling and trackpad gestures (all in
  Atrium; gestures since 26 Nov 2026, COS-308). Nothing leaves the machine.
- **Remote.** Workspace and split navigation, carried to the herdr host over
  one multiplexed ssh connection. Atrium runs this route since 25 Nov 2026
  (COS-299); the reasoning on this page still holds for it.
- **House.** The right knob, as HTTP calls to Home Assistant for the office's
  music. Atrium runs this route too since 26 Nov 2026 (COS-305).
- **Background.** The backlight, polled every minute from Home Assistant's
  house mode and set over HID (Atrium since 26 Nov 2026, COS-307), and the
  Mac's Now Playing entry for the office's music, polled every 5 s (Atrium
  since 26 Nov 2026, COS-309; a launchd agent before).

Only the two middle paths leave the machine, and that is the useful part. A
control that works everywhere except inside the terminal is an ssh fault, not
a keyboard fault. That single distinction has resolved the same report twice,
both times after the keyboard was suspected first. A right knob that does
nothing while the left one works is the same reading for Home Assistant.

The knob does not name a player. It asks Home Assistant which office player
is playing on each use, because the room has several and the one that plays
changes; the house already knows, and a name fixed here would be a second
copy of that knowledge going stale. The list of candidates is in the conf
file, not in the code, for the same reason: the knob and Now Playing
both read it, and entity IDs describe a house, not this repo.

Now Playing is the one door into other software that needs no cooperation
from it. Bartender's Top Shelf has no status of its own to write to, but it
reads the system's Now Playing like everything else does, so publishing there
reaches it, Control Center and the play key at once. Now Playing has no field
for a volume step or a three minute break, so those are drawn by the router
itself, in its own bezel. Top Shelf's agent bridge can be made to show them,
dressed as a finished prompt; that was tried and dropped, because a notice
reading "Claude finished - Vol 55%" is a lie about who did what.

## One bezel

Everything the router draws is a single form, borrowed from Quicksilver: a
panel of large square panes, each a picture over a label, one line of detail
beneath. The stage picker is the reason. A stage is a set of apps, and the
fastest way to tell two apps apart is their icons at a size where they can be
recognised, which a list row has no room for. Once that form existed, the
volume step and the play state became one-pane cases of it, and the router
stopped having unrelated looks. Atrium carries the same form as one reusable
piece (`Bezel.swift`), with the stage picker in it as the one form that waits
for a pick; Hammerspoon draws nothing any more, so its startup notice went
with the move (COS-308).

## The ssh master is load bearing, not an optimisation

Measured on this link: a call through a live master takes about 0.09s, and a
cold one about 6.9s. The router gives a remote call three seconds before it
gives up and falls back to a local keystroke. A cold call therefore cannot
succeed; it is always killed, and the press appears to do nothing.

`ControlPersist=yes` keeps a live master alive indefinitely, but it rebuilds
nothing once one dies, and the aggressive `ServerAlive` settings drop the
master after four seconds of stall, which a laptop sleep or a network reroute
does easily. Nothing then rebuilt it until a keypress tried and failed, so the
first press after every blip was silently eaten, and the thing recovered on
its own only once something else happened to warm the connection.

The health tick now rebuilds the master itself, which turns a blip into thirty
seconds of staleness instead of a lost keypress. Keeping that connection warm
is the feature, not a tuning detail.

## Re-arm rather than check

macOS disables event taps behind your back, and the tap's own `isEnabled`
reports Hammerspoon's flag rather than whether the system still routes events
to it. A watchdog built on that method never fires, because every diagnostic
still looks healthy while the tap is dead. The health tick therefore re-arms
unconditionally instead of asking first. Re-arming a working tap costs
microseconds, and asking a broken one costs the whole feature. Atrium's taps
(M2 and M3, the gestures, copy on select in Herdr) follow the same rule.

## Poll rather than watch

The same shape appears twice more. `hs.usb.watcher` never delivered a single
event for the wireless receiver, because it sits in a Thunderbolt dock and so
hangs off a different USB controller than a root port. The failure had no
symptom: no error, no exception, and the field name the callback tested was
the right one.

The rule this leaves behind: when a notification mechanism can be absent
without saying so, poll for the state instead. Presence is checked on the
health tick that already runs, and only talks to the keyboard when presence
actually changes, so the steady state costs one query. Atrium's polling-rate
menubar keeps this rule: it asks IOKit for the interface every thirty seconds
rather than subscribing to its notifications. The cost is up to thirty
seconds of latency, which beats a mechanism that is silent.

## One writer for the keyboard

Each HID command has one writer, so report framing lives in one place per
command. When the polling rate moved to Atrium (COS-306) it left
`keylight.py` rather than being written twice: Lua had no hidapi, which is why
the menubar used to shell out to `keylight.py`, and Atrium speaks IOKit HID
natively (`Q11HID.swift`). The backlight followed it into the same client
(COS-307), and `keylight.py` is gone.
The same reasoning puts the trackpad and window actions behind the `rcmd`
binary rather than reimplementing them.

Two writers would also fight for the device. The Launcher already does this:
an open Launcher tab reads the same interface and can steal a reply, which is
why reads retry rather than trusting a single round trip.

## Fail soft, everywhere

Every herdr action names a local fallback, so a dead herdr host degrades to
plain keystrokes instead of dead keys. The right knob is the one exception:
an unreachable Home Assistant fails only after a timeout, and volume
steps arriving late are worse than a knob that does nothing. Atrium caps each
call at five seconds for the same reason. Setting the remote host to nil is
supported and documented, and the backlight treats an unreachable Home
Assistant as a reason to fall back to the clock rather than to leave the
keyboard wrong.

The same instinct covers the gesture layer, which stands down entirely while a
game owns the trackpad, and the backlight poll, which is a no operation when
the effect already matches so it does not burn a flash write.

## What is deliberately not solved

Battery level. The keyboard exposes no HID battery usage, the Launcher never
queries one for this board, and the receiver answers the documented vendor
request with zeros and then silence. The evidence and the untested routes are
in [protocol](../protocol.md) so the ground is not covered twice.

Radio commercials. The double press is a fixed three minute pause because
nothing better is known to the house: Music Assistant has no ad detection.
One 25 minute log of Radio Veronica (2026-11-18) showed a single song title
held for about ten minutes, which suggests the station keeps the last title
through a break and changes it when music returns. That is inferred from
timing in one log and not verified.

The jingle route is measured. One recorded hour (2026-11-19, 10:50 to 11:50)
with the blocks marked by ear has a sting of under a second that opens and
closes each run of commercials: six hits at a match of 0.88 or better and
nothing else above 0.66. It comes in pairs, so "mute on one, unmute on the
next" holds, and two of the three runs were 181 seconds. A longer block
contains two pairs with news between them. A second, different jingle can
open a block half a minute before the first sting; it appeared once and is
not fingerprinted. The recording, the sting and the titles are in
`~/Desktop/veronica/`. The listener that would act on this is not built, and
belongs with the music stack rather than in this repo.

## Where this stands against everyone else

Checked 2026-11-18. Nobody has published a better host side setup for the Q11
Ultra; what exists is Launcher remaps. Keychron published its ZMK fork on
2026-05-23 (branch `rtl8762g`), with about fifty boards and not this one, so
custom firmware is still not an option and the split of work here, plain
signals from the board and meaning on the Mac, stays the right one. The
board's own firmware version was not checked in that pass.
