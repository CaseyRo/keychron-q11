-- keychron-q11 — Q11 Ultra signal-key router. Runs on the Mac the keyboard
-- is attached to; herdr lives on cc1 and is reached over ssh.
-- The keyboard sends dumb F13–F23 signals (bound in Keychron Launcher,
-- see docs/launcher-keymap.md); this file decides what they mean.

local REMOTE = "cc1"
local REMOTE_HELPER = "dev/keychron-q11/bin/q11-herdr"
-- Terminals showing the cc1/herdr session, in preference order.
local TERMINALS = { "dev.warp.Warp-Stable", "com.googlecode.iterm2" }

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
  jumpWorkspace(code == F14 and 2 or 3)
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

-- Right encoder on the fn layer (F21/F22 rotate, F23 press): Spotify,
-- independent of system volume. Base layer stays plain media volume
-- (bound on the keyboard itself, never reaches us).
hs.hotkey.bind({}, "f21", function()
  hs.spotify.setVolume(math.max(0, hs.spotify.getVolume() - 3))
end)
hs.hotkey.bind({}, "f22", function()
  hs.spotify.setVolume(math.min(100, hs.spotify.getVolume() + 3))
end)
hs.hotkey.bind({}, "f23", function()
  hs.spotify.playpause()
end)

require("hs.ipc") -- enables `hs -c "hs.reload()"` for remote config reloads

hs.alert.show("keychron-q11 armed")
