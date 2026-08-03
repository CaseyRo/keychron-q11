-- keychron-q11 — Q11 Ultra signal-key router. Runs on the Mac the keyboard
-- is attached to. The keyboard sends dumb F13–F20 signals (bound in
-- Keychron Launcher, see docs/launcher-keymap.md); this file decides what
-- they mean.

-- ── config ──────────────────────────────────────────────────────────────
-- Optional: an ssh host running herdr (terminal workspace manager) for
-- real workspace/split navigation. Set to nil if you don't use herdr —
-- everything degrades to plain Cmd+N / tab-cycling keystrokes.
local REMOTE = "cc1"
local REMOTE_HELPER = "dev/keychron-q11/bin/q11-herdr"
-- Terminals to treat as "the cockpit", in preference order.
local TERMINALS = { "dev.warp.Warp-Stable", "com.googlecode.iterm2" }
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

-- Run the herdr helper on cc1; on failure fall back to a plain keystroke.
-- ControlPersist keeps one multiplexed connection warm so encoder detents
-- cost ~tens of ms, not a full ssh handshake each.
local function herdr(args, fallback)
  if not REMOTE then
    if fallback then fallback() end
    return
  end
  local sshArgs = {
    "-o", "BatchMode=yes",
    "-o", "ConnectTimeout=2",
    "-o", "ControlMaster=auto",
    "-o", "ControlPath=/tmp/keychron-q11-%r@%h",
    "-o", "ControlPersist=300",
    REMOTE, REMOTE_HELPER,
  }
  for _, a in ipairs(args) do table.insert(sshArgs, a) end
  hs.task.new("/usr/bin/ssh", function(exitCode)
    if exitCode ~= 0 and fallback then fallback() end
  end, sshArgs):start()
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
  -- Defer the work off the tap callback. focusTerminal() goes through the
  -- window server, which takes seconds when the Mac is loaded (SkyLight
  -- saturated, swapping). macOS blocks the ENTIRE input stream until a keyDown
  -- tap returns, so doing that inline stalls every keystroke system-wide — not
  -- just this one. doAfter(0) runs it on the next runloop pass instead, so a
  -- slow jump stays a slow jump rather than freezing typing.
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
-- Base layer stays plain media volume (bound on the keyboard itself,
-- never reaches us). macOS has NO keycodes for F21-F24 — the virtual
-- keycode table ends at F20 and the OS drops those HID usages — and
-- F13-F20 are all spent, so the fn layer sends hyper-modified F18-F20.
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

-- Scroll-layer fallback for the right encoder, only needed if Launcher
-- has no mouse-wheel keycodes (KC_WH_U/KC_WH_D — prefer those: they need
-- no host code at all). Scrolls whatever is under the pointer.
hs.hotkey.bind(HYPER, "f14", function()
  hs.eventtap.scrollWheel({ 0, 3 }, {}, "line") -- up
end)
hs.hotkey.bind(HYPER, "f15", function()
  hs.eventtap.scrollWheel({ 0, -3 }, {}, "line") -- down
end)
hs.hotkey.bind(HYPER, "f16", function()
  hs.eventtap.scrollWheel({ 0, -1000000 }, {}, "pixel") -- jump to bottom
end)

-- Reload on config change. Without this a `git pull` on the router host is
-- inert until Hammerspoon is restarted by hand — which reads as "the router
-- died". Replaces the old hs.ipc line: `hs -c` needs hs.ipc.cliInstall(),
-- which was never run, so remote reload never actually worked.
--
-- Filter to .lua: hs.configdir is usually a symlink into this git worktree, so
-- an unfiltered watcher reloads on .DS_Store, editor swap files, Spoons/ and
-- every git index write — and each reload rebuilds the eventtap below.
local function reloadOnLuaChange(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end
-- global on purpose, same reason as q11MTap: a local watcher gets GC'd and
-- auto-reload silently stops working.
q11Watcher = hs.pathwatcher.new(hs.configdir, reloadOnLuaChange):start()

-- Reload rebinds q11MTap but does NOT stop the tap the old config started, and
-- a started tap stays live until it happens to be collected. Two live taps both
-- swallow the same F14/F15 press, so one keypress fires jumpWorkspace twice.
function hs.shutdownCallback()
  if q11MTap then q11MTap:stop() end
end

hs.alert.show("keychron-q11 armed")
