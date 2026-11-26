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
-- (Trackpad.swift), and copy on select with the Herdr theme the same day,
-- COS-310 (HerdrDesk.swift). This file keeps only its own reload and the
-- Storykeep meeting watcher, until Hammerspoon retires (COS-311).
-- ────────────────────────────────────────────────────────────────────────

-- Reload on config change, so a git pull isn't inert until Hammerspoon is
-- restarted by hand. Filtered to .lua: hs.configdir is a symlink into this
-- worktree, so an unfiltered watcher fires on .DS_Store and every git index
-- write.
q11Watcher = hs.pathwatcher.new(hs.configdir, function(paths)
  for _, p in ipairs(paths) do
    if p:sub(-4) == ".lua" then return hs.reload() end
  end
end):start()

-- FSEvents streams are OS resources GC won't promptly release, and a reload
-- builds a new one without stopping the old.
function hs.shutdownCallback()
  if q11Watcher then q11Watcher:stop() end
end

-- Storykeep's meeting watcher lives in casey-claude-setup, which no other
-- host that runs this router has. Guarded so a missing repo costs a console
-- line instead of the tail of this file.
local ok, meetings = pcall(dofile, os.getenv("HOME") .. "/dev/casey-claude-setup/companion/companions/storykeep/orchestration/meetings.lua")
storykeepMeetings = ok and meetings or nil -- global on purpose: it outlives this file
if not ok then print("storykeep meetings not loaded: " .. tostring(meetings)) end
