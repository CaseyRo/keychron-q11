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

-- ── trackpad gestures ───────────────────────────────────────────────────
-- Replaces the BetterTouchTool preset this machine used to run. macOS's own
-- three- and four-finger swipes are all switched off here (Trackpad → More
-- Gestures; every TrackpadThree/FourFinger*SwipeGesture default reads 0, and
-- showMissionControlGestureEnabled = 0), so nothing competes for these —
-- `cmd` below is a preference, not a workaround. Set a row's cmd to false to
-- claim the bare swipe instead.
local RCMD = "/opt/homebrew/bin/rcmd" -- absolute: hs.task gets no PATH
local function rcmd(...)
  hs.task.new(RCMD, nil, { ... }):start()
end

local GESTURES = {
  { fingers = 3, dir = "up",   cmd = true, action = function() rcmd("expose") end },
  { fingers = 3, dir = "down", cmd = true, action = hs.spaces.toggleShowDesktop },
}
-- Travel a swipe must cover to count, as a fraction of the trackpad. This is
-- the tuning knob: raise it if resting fingers trigger something, lower it if
-- deliberate swipes get dropped. Trackpads differ, so expect to touch it —
-- set q11SwipeDebug below and read the measured numbers with q11SwipeReport().
local SWIPE_MIN = 0.06
-- How much further a swipe must run along its axis than across it, so a
-- sloppy diagonal resolves to one direction rather than to neither.
local SWIPE_RATIO = 1.5
-- macOS interleaves gesture events carrying no touches at all, between the
-- ones that carry the fingers. Treating a zero-touch event as "fingers lifted"
-- chopped one measured swipe into ~25 fragments of a few thousandths each, so
-- a zero-touch event means "no news" and the gesture ends on this quiet timer.
local SWIPE_IDLE = 0.08

-- Pure, so it can be checked without a trackpad — see q11SwipeSelfTest below.
local function swipeDir(dx, dy)
  local adx, ady = math.abs(dx), math.abs(dy)
  if ady >= SWIPE_MIN and ady > adx * SWIPE_RATIO then
    return dy > 0 and "up" or "down" -- normalizedPosition origin is bottom-left
  elseif adx >= SWIPE_MIN and adx > ady * SWIPE_RATIO then
    return dx > 0 and "right" or "left"
  end
end

function q11SwipeSelfTest()
  local cases = {
    { 0, 0.2, "up" }, { 0, -0.2, "down" },
    { 0.2, 0, "right" }, { -0.2, 0, "left" },
    { 0, 0.05, nil },       -- too short to be deliberate
    { 0.15, 0.15, nil },    -- true diagonal: no axis wins, stay silent
    { 0.03, 0.2, "up" },    -- normal hand drift still resolves
  }
  for _, c in ipairs(cases) do
    local got = swipeDir(c[1], c[2])
    assert(got == c[3], ("swipeDir(%s,%s)=%s want %s")
      :format(c[1], c[2], tostring(got), tostring(c[3])))
  end
  return "swipe selftest ok"
end

-- Gesture events stream continuously while fingers are down and a tap callback
-- blocks delivery until it returns, so this stays arithmetic only and hands the
-- action to the next runloop pass — same reason as the F14/F15 tap above.
local function runGesture(n, cmdHeld, dir)
  for _, g in ipairs(GESTURES) do
    if g.fingers == n and g.dir == dir and g.cmd == cmdHeld then
      hs.timer.doAfter(0, g.action)
      return true
    end
  end
  return false
end

-- True once this finger count + modifier could still become a bound swipe, in
-- any direction. Gates event swallowing, so ordinary two-finger scrolling is
-- never touched — only a combination already spoken for gets suppressed.
local function gestureArmed(n, cmdHeld)
  for _, g in ipairs(GESTURES) do
    if g.fingers == n and g.cmd == cmdHeld then return true end
  end
  return false
end

-- Calibration rig for SWIPE_MIN on a trackpad that reads differently from the
-- one this was tuned on:
--   hs -c "q11SwipeDebug = true"   swipe a few times   hs -c "q11SwipeReport()"
-- A ring buffer, not print(): output from a tap callback never reaches
-- hs.console.getConsole(), so a printed number is unreadable over hs -c.
q11SwipeDebug = false
q11SwipeLog = {}

function q11SwipeReport()
  return #q11SwipeLog == 0 and "no swipes recorded" or table.concat(q11SwipeLog, "\n")
end

q11Swipe = nil      -- in-flight gesture; global so a reload can't strand it
q11SwipeTimer = nil -- reused, not recreated: this runs thousands of times a swipe

-- End of gesture. The action has already fired by now (mid-swipe, the moment
-- the threshold was crossed) — this only records the full travel for
-- calibration and clears the slate for the next one.
local function finalizeSwipe()
  local s = q11Swipe
  q11Swipe, q11SwipeTimer = nil, nil
  if not s then return end
  if q11SwipeDebug then
    q11SwipeLog[#q11SwipeLog + 1] = ("fingers=%d dx=%+.4f dy=%+.4f cmd=%s fired=%s")
      :format(s.n, s.x - s.x0, s.y - s.y0, tostring(s.cmd), tostring(s.fired or false))
    if #q11SwipeLog > 20 then table.remove(q11SwipeLog, 1) end
  end
end

local SCROLL = hs.eventtap.event.types.scrollWheel

q11GestureTap = hs.eventtap.new({ hs.eventtap.event.types.gesture, SCROLL }, function(e)
  -- The fingers driving a swipe also drive a scroll, on a separate event
  -- stream: without swallowing it the window underneath scrolls for as long as
  -- the swipe takes to recognise. Gated on `armed`, so this can only ever
  -- suppress a finger count and modifier already bound to a gesture — plain
  -- two-finger scrolling never reaches the branch.
  if e:getType() == SCROLL then
    local s = q11Swipe
    if not (s and s.armed) then return false end
    -- Hold the window open past the last touch, or momentum scrolling lands
    -- in the app right after the gesture is recognised.
    if q11SwipeTimer then q11SwipeTimer:setNextTrigger(SWIPE_IDLE) end
    return true
  end

  local touches = e:getTouches()
  if not touches then return false end
  local n, sx, sy = 0, 0, 0
  for _, t in ipairs(touches) do
    -- "indirect" is a trackpad; "direct" would be a touchbar
    if t.type == "indirect" and t.touching and t.normalizedPosition then
      n = n + 1
      sx, sy = sx + t.normalizedPosition.x, sy + t.normalizedPosition.y
    end
  end
  if n == 0 then return false end -- no news; the idle timer decides when it ended

  local s = q11Swipe
  local cx, cy = sx / n, sy / n
  if not s or n > s.n then
    -- Anchor when the last finger lands, not the first: fingers touch down on
    -- different events, and anchoring early folds that stagger into the delta.
    s = { n = n, x0 = cx, y0 = cy, x = cx, y = cy, cmd = false, armed = false }
    q11Swipe = s
  elseif n == s.n then
    s.x, s.y = cx, cy -- fingers lifting (n < s.n) must not drag the endpoint
  end
  if e:getFlags().cmd then s.cmd = true end -- latched: an early release still counts
  s.armed = gestureArmed(s.n, s.cmd)

  -- Fire the moment the threshold is crossed rather than on release: waiting
  -- for the fingers to lift makes a gesture that is already recognisable feel
  -- like it lagged. `fired` keeps one swipe to one action.
  if not s.fired then
    local dir = swipeDir(s.x - s.x0, s.y - s.y0)
    if dir and runGesture(s.n, s.cmd, dir) then s.fired = true end
  end

  if q11SwipeTimer then
    q11SwipeTimer:setNextTrigger(SWIPE_IDLE)
  else
    q11SwipeTimer = hs.timer.doAfter(SWIPE_IDLE, finalizeSwipe)
  end
  return s.armed -- swallow the gesture stream too, in case the app reads it directly
end)
q11GestureTap:start()

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
  if q11GestureTap then q11GestureTap:stop() end
  if q11Watcher then q11Watcher:stop() end
  if q11Health then q11Health:stop() end
end

-- macOS silently disables event taps and isEnabled() keeps reporting true, so a
-- watchdog that checks it never fires. Re-arm unconditionally; costs microseconds.
q11Health = hs.timer.doEvery(30, function()
  if q11MTap then q11MTap:stop():start() end
  if q11GestureTap then
    q11GestureTap:stop():start()
    -- a re-arm mid-swipe would leave the next event mis-anchored
    if q11SwipeTimer then q11SwipeTimer:stop() end
    q11Swipe, q11SwipeTimer = nil, nil
  end
end)

hs.alert.show("keychron-q11 armed")
