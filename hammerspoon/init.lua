-- steuerhorn — Q11 Ultra signal-key router. Runs on the Mac the keyboard
-- is attached to; herdr lives on cc1 and is reached over ssh.
-- The keyboard sends dumb F13–F23 signals (bound in Keychron Launcher,
-- see docs/launcher-keymap.md); this file decides what they mean.

local REMOTE = "cc1"
local REMOTE_HELPER = "dev/steuerhorn/bin/steuerhorn-herdr"
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
    "-o", "ControlPath=/tmp/steuerhorn-%r@%h",
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
for i = 1, 5 do
  hs.hotkey.bind({}, "f" .. (12 + i), function()
    focusTerminal()
    herdr({ "focus", tostring(i) }, function()
      hs.eventtap.keyStroke({ "cmd" }, tostring(i))
    end)
  end)
end

-- Left encoder rotate (F18 = ccw, F19 = cw): in the terminal cycle herdr
-- workspaces (fallback: tab cycling); elsewhere move through macOS Spaces.
local function leftEncoder(dir, spaceKey, tabKey)
  return function()
    if terminalFrontmost() then
      herdr({ dir }, function()
        hs.eventtap.keyStroke({ "cmd", "shift" }, tabKey)
      end)
    else
      hs.eventtap.keyStroke({ "ctrl" }, spaceKey)
    end
  end
end
hs.hotkey.bind({}, "f18", leftEncoder("prev", "left", "["))
hs.hotkey.bind({}, "f19", leftEncoder("next", "right", "]"))

-- Left encoder press (F20): Mission Control.
hs.hotkey.bind({}, "f20", function()
  hs.spaces.toggleMissionControl()
end)

-- Right encoder on the fn layer (F21/F22 rotate, F23 press): Spotify,
-- independent of system volume. Base layer stays plain media volume
-- (bound on the keyboard itself, never reaches us).
hs.hotkey.bind({}, "f21", function()
  hs.spotify.setVolume(math.max(0, hs.spotify.getVolume() - 6))
end)
hs.hotkey.bind({}, "f22", function()
  hs.spotify.setVolume(math.min(100, hs.spotify.getVolume() + 6))
end)
hs.hotkey.bind({}, "f23", function()
  hs.spotify.playpause()
end)

hs.alert.show("steuerhorn armed")
