-- keychron-q11 — Q11 Ultra signal-key router. Runs on the Mac the keyboard
-- is attached to. The keyboard sends dumb F13–F20 signals (bound in
-- Keychron Launcher, see docs/launcher-keymap.md); this file decides what
-- they mean.
--
-- The macOS traps this works around, and the measurements behind the ssh
-- settings, are in README.md → Three macOS traps / Troubleshooting.

require("hs.ipc") -- `hs -c "..."` introspection; first, so a later throw is diagnosable

-- ── config ──────────────────────────────────────────────────────────────
-- Optional: an ssh host running herdr (terminal workspace manager) for
-- real workspace/split navigation. Set to nil if you don't use herdr —
-- everything degrades to plain Cmd+N / tab-cycling keystrokes.
local REMOTE = "cc1"
local REMOTE_HELPER = "dev/keychron-q11/bin/q11-herdr"
-- Terminals to treat as "the cockpit", in preference order.
local TERMINALS = { "dev.warp.Warp-Stable", "com.googlecode.iterm2" }
-- Ceiling on one herdr call, seconds. Past this, fall back to the local
-- keystroke rather than let presses queue behind a dead ssh.
local HERDR_TIMEOUT = 3
-- ────────────────────────────────────────────────────────────────────────

local function terminalFrontmost()
  local app = hs.application.frontmostApplication()
  return app and hs.fnutils.contains(TERMINALS, app:bundleID())
end

local function focusTerminal()
  for _, id in ipairs(TERMINALS) do
    if hs.application.get(id) then
      hs.application.launchOrFocusByBundleID(id)
      return
    end
  end
  hs.application.launchOrFocusByBundleID(TERMINALS[1])
end

-- One multiplexed connection carries every press: ~85ms warm vs ~2.6s cold.
-- %n not %h (Tailscale re-addresses and orphans the master); ControlPersist=yes
-- not a finite value (idle expiry put the cold path back on the next keypress);
-- ServerAlive* because ConnectTimeout bounds only the TCP connect.
local SSH_OPTS = {
  "-o", "BatchMode=yes",
  "-o", "ConnectTimeout=2",
  "-o", "ControlMaster=auto",
  "-o", "ControlPath=/tmp/keychron-q11-%r@%n",
  "-o", "ControlPersist=yes",
  "-o", "ServerAliveInterval=2",
  "-o", "ServerAliveCountMax=2",
}

-- Run the herdr helper on cc1; on failure fall back to a plain keystroke.
local function herdr(args, fallback)
  if not REMOTE then
    if fallback then fallback() end
    return
  end
  local sshArgs = table.move(SSH_OPTS, 1, #SSH_OPTS, 1, { })
  sshArgs[#sshArgs + 1] = REMOTE
  sshArgs[#sshArgs + 1] = REMOTE_HELPER
  for _, a in ipairs(args) do sshArgs[#sshArgs + 1] = a end
  local task = hs.task.new("/usr/bin/ssh", function(exitCode)
    if exitCode ~= 0 and fallback then fallback() end
  end, sshArgs)
  task:start()
  -- terminate() SIGTERMs, so the callback above fires with exitCode 15 and runs
  -- the fallback itself — no second path needed here.
  hs.timer.doAfter(HERDR_TIMEOUT, function()
    if task:isRunning() then task:terminate() end
  end)
end

-- M1–M5 (F13–F17): the flight-deck selector. From anywhere, focus the
-- terminal and jump to herdr workspace N; herdr down → terminal tab N.
local function jumpWorkspace(n)
  focusTerminal()
  herdr({ "focus", tostring(n) }, function()
    hs.eventtap.keyStroke({ "cmd" }, tostring(n))
  end)
end

for key, ws in pairs({ f13 = 1, f16 = 4, f17 = 5 }) do
  hs.hotkey.bind({}, key, function() jumpWorkspace(ws) end)
end

-- macOS eats bare F14/F15 as legacy display-brightness keys before hotkey
-- registration sees them — an event tap runs earlier and swallows them.
local F14, F15 = 107, 113
q11MTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
  local code = e:getKeyCode()
  if code ~= F14 and code ~= F15 then return false end
  local f = e:getFlags()
  if f.cmd or f.alt or f.ctrl or f.shift then return false end
  -- macOS blocks the ENTIRE input stream until a keyDown tap returns, and
  -- focusTerminal() can take seconds on a loaded Mac. doAfter(0) moves it to the
  -- next runloop pass so a slow jump never freezes typing system-wide.
  local ws = code == F14 and 2 or 3
  hs.timer.doAfter(0, function() jumpWorkspace(ws) end)
  return true -- delete the event so brightness never fires
end)
q11MTap:start() -- global on purpose: locals get GC'd and the tap dies

-- Left encoder rotate (F18 = ccw, F19 = cw): in the terminal walk herdr
-- splits, falling through to workspace cycling at the edge (M-keys own
-- direct jumps); elsewhere move through macOS Spaces.
local function leftEncoder(dir, spaceKey, tabKey)
  return function()
    if terminalFrontmost() then
      herdr({ "cycle", dir }, function()
        hs.eventtap.keyStroke({ "cmd", "shift" }, tabKey)
      end)
    else
      hs.eventtap.keyStroke({ "ctrl" }, spaceKey)
    end
  end
end
hs.hotkey.bind({}, "f18", leftEncoder("prev", "left", "["))
hs.hotkey.bind({}, "f19", leftEncoder("next", "right", "]"))

-- Left encoder press (F20): zoom the focused split in the terminal,
-- Mission Control everywhere else.
hs.hotkey.bind({}, "f20", function()
  if terminalFrontmost() then
    herdr({ "zoom" }, hs.spaces.toggleMissionControl)
  else
    hs.spaces.toggleMissionControl()
  end
end)

-- Right encoder on the fn layer: Spotify, independent of system volume.
-- Base layer stays plain media volume (bound on the keyboard itself, never
-- reaches us). F21-F24 don't exist on macOS and F13-F20 are spent, so the fn
-- layer sends hyper-modified F18-F20.
local HYPER = { "cmd", "alt", "ctrl" }
hs.hotkey.bind(HYPER, "f18", function()
  hs.spotify.setVolume(math.min(100, hs.spotify.getVolume() + 3))
end)
hs.hotkey.bind(HYPER, "f19", function()
  hs.spotify.setVolume(math.max(0, hs.spotify.getVolume() - 3))
end)
hs.hotkey.bind(HYPER, "f20", function()
  hs.spotify.playpause()
end)

-- Scroll up/down are pure keyboard (KC_WH_U/KC_WH_D). Jump-to-bottom has no
-- wheel keycode, so it stays here.
hs.hotkey.bind(HYPER, "f16", function()
  hs.eventtap.scrollWheel({ 0, -1000000 }, {}, "pixel")
end)

-- Reload on config change, so a git pull isn't inert until Hammerspoon is
-- restarted by hand. Filtered to .lua: hs.configdir is a symlink into this
-- worktree, so an unfiltered watcher fires on .DS_Store and every git index
-- write, and each reload rebuilds the tap.
q11Watcher = hs.pathwatcher.new(hs.configdir, function(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then return hs.reload() end
  end
end):start()

-- Taps and FSEvents streams are OS resources GC won't promptly release, and a
-- reload builds new ones without stopping the old — two live taps swallow the
-- same press twice.
function hs.shutdownCallback()
  if q11MTap then q11MTap:stop() end
  if q11Watcher then q11Watcher:stop() end
  if q11Health then q11Health:stop() end
end

-- macOS silently disables event taps and isEnabled() keeps reporting true, so a
-- watchdog that checks it never fires. Re-arm unconditionally; costs microseconds.
q11Health = hs.timer.doEvery(30, function()
  if q11MTap then q11MTap:stop():start() end
end)

hs.alert.show("keychron-q11 armed")
