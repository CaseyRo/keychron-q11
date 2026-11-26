-- keychron-q11 — Q11 Ultra signal-key router. Runs on the Mac the keyboard
-- is attached to. The keyboard sends dumb F13–F20 signals (bound in
-- Keychron Launcher, see docs/launcher-keymap.md); this file decides what
-- they mean.
--
-- The macOS traps this works around, and the measurements behind the ssh
-- settings, are in README.md → Four macOS traps / Troubleshooting.

require("hs.ipc") -- `hs -c "..."` introspection; first, so a later throw is diagnosable

-- ── config ──────────────────────────────────────────────────────────────
-- M1–M5 and the left knob (F13–F20) moved to Atrium (~/dev/atrium, Keys.swift)
-- on 25 Nov 2026, COS-299; the right knob, its ⌘⌃⌥ keys and the office music
-- followed on 26 Nov 2026, COS-305 (OfficeMusic.swift, Bezel.swift), and the
-- polling-rate menubar the same day, COS-306 (PollingMenu.swift), and the
-- trackpad gestures with the stage picker the same day, COS-308
-- (Trackpad.swift). This file keeps the rest, and no hotkeys and no bezel,
-- until it moves too.
-- Herdr desktop, for copy on select below.
local HERDR_APP_ID = "dev.herdr.app"
local HERDR_APP = os.getenv("HOME") .. "/.local/bin/herdr-app"
-- This repo, for bin/herdr-daylight below. Spelled out rather than derived
-- from hs.configdir: install.sh symlinks ~/.hammerspoon to this directory, so
-- `hs.configdir .. "/.."` reaches the repo only for a symlinked install.
local REPO = os.getenv("HOME") .. "/dev/keychron-q11"
-- ────────────────────────────────────────────────────────────────────────

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
  if q11CopyTap then q11CopyTap:stop() end
  if q11Watcher then q11Watcher:stop() end
  if q11Health then q11Health:stop() end
end

-- ── Herdr desktop ───────────────────────────────────────────────────────
-- Copy on select, as Warp does: a drag or a double/triple click released in
-- Herdr copies the terminal's selection. terminal.copy rather than ⌘C, so
-- nothing reaches the shell; with no selection it leaves the clipboard alone.
local mouse = hs.eventtap.event.types
q11DragSeen = false
q11CopyTap = hs.eventtap.new({ mouse.leftMouseDragged, mouse.leftMouseUp }, function(e)
  if e:getType() == mouse.leftMouseDragged then
    q11DragSeen = true
    return false
  end
  local multi = e:getProperty(hs.eventtap.event.properties.mouseEventClickState) >= 2
  local app = hs.application.frontmostApplication()
  if (q11DragSeen or multi) and app and app:bundleID() == HERDR_APP_ID then
    hs.task.new(HERDR_APP, nil, { "do", "terminal.copy" }):start()
  end
  q11DragSeen = false
  return false
end)
q11CopyTap:start()

-- Theme follows the HA house mode (bin/herdr-daylight has the mapping). Every
-- 5 min, plus on wake so opening the lid at night isn't a flash of daylight.
local function herdrDaylight()
  hs.task.new(REPO .. "/bin/herdr-daylight", nil, {}):start()
end
q11DaylightTimer = hs.timer.doEvery(300, herdrDaylight)
q11DaylightWake = hs.caffeinate.watcher.new(function(event)
  if event == hs.caffeinate.watcher.systemDidWake then herdrDaylight() end
end):start()
herdrDaylight()

-- macOS silently disables event taps and isEnabled() keeps reporting true, so a
-- watchdog that checks it never fires. Re-arm unconditionally; costs microseconds.
q11Health = hs.timer.doEvery(30, function()
  if q11CopyTap then q11CopyTap:stop():start() end
end)

-- Storykeep's meeting watcher lives in casey-claude-setup, which no other
-- host that runs this router has. Guarded so a missing repo costs a console
-- line instead of the tail of this file.
local ok, meetings = pcall(dofile, os.getenv("HOME") .. "/dev/casey-claude-setup/companion/companions/storykeep/orchestration/meetings.lua")
storykeepMeetings = ok and meetings or nil -- global on purpose: it outlives this file
if not ok then print("storykeep meetings not loaded: " .. tostring(meetings)) end
