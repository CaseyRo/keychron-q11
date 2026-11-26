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
-- followed on 26 Nov 2026, COS-305 (OfficeMusic.swift, Bezel.swift). This file
-- keeps the rest, and no hotkeys, until it moves too.
-- Herdr desktop, for copy on select below.
local HERDR_APP_ID = "dev.herdr.app"
local HERDR_APP = os.getenv("HOME") .. "/.local/bin/herdr-app"
-- This repo, and uv, for the polling-rate menubar: it shells out to
-- keylight.py because Lua has no hidapi. Absolute, because hs.task gets no
-- PATH. Spelled out rather than derived from hs.configdir: install.sh symlinks
-- ~/.hammerspoon to this directory, so `hs.configdir .. "/.."` does reach the
-- repo — but only for a symlinked install, and it breaks silently for a copied
-- one. A constant is one line and cannot be wrong.
local REPO = os.getenv("HOME") .. "/dev/keychron-q11"
local UV = "/opt/homebrew/bin/uv"
-- Apps that own the trackpad outright, by bundle ID. Games read raw finger
-- movement, so the gesture layer stands down while one is frontmost. Read a
-- real ID rather than guessing — by name, since asking for the frontmost app
-- from a terminal just names the terminal:
--   osascript -e 'id of app "Factorio"'
-- Steam itself is listed for its own window; a game launched through Steam is
-- a separate app and needs its own line here.
local MUTE_APPS = {
  ["com.factorio"] = true,
  ["com.valvesoftware.steam"] = true,
}
-- ────────────────────────────────────────────────────────────────────────

-- ── look ────────────────────────────────────────────────────────────────
-- Everything this file draws is one thing: a bezel after Quicksilver's, a
-- translucent rounded panel of large square panes, each a big picture over a
-- centred label, with one line of detail underneath. Quicksilver's because the
-- job is the same (pick a thing by looking at it, from the keyboard) and
-- because a stage is best named by the apps in it, which is what the panes
-- have room to show. Atrium's Bezel.swift is its port and draws the right
-- knob's notices; this one stays for the stage picker
-- until COS-308 moves it. Colours are Herdr's Cobalt×CDiT theme
-- (~/.config/herdr-app/themes/cobalt-cdit-evening.json), copied, not read at
-- load: a missing theme file must not take the picker down.
-- shortcut: evening only, the day (moss) theme is not followed; read the
-- active theme in herdrDaylight if the mismatch ever shows.
-- A little see-through, as Quicksilver's was, but only a little: a canvas
-- cannot blur what is behind it, and at 0.88 the page underneath read straight
-- through the labels.
local COBALT = { hex = "#122738", alpha = 0.93 }
local YELLOW = { hex = "#ffc600" } -- the cursor colour, Cobalt's one loud note
local FG     = { hex = "#e6edf3" }
local MUTED  = { hex = "#abb1b8" }
local PANE, GAP, PAD, FOOT, EDGE = 176, 10, 14, 32, 48 -- EDGE: room for the shadow

q11Bezel, q11BezelKeys = nil, nil -- globals: a local canvas or modal is GC'd
local function closeBezel(now)
  if q11BezelKeys then q11BezelKeys:exit(); q11BezelKeys:delete(); q11BezelKeys = nil end
  local c = q11Bezel
  if not c then return end
  q11Bezel = nil
  if now then return c:delete() end
  c:hide(0.45) -- the long fade out is half of what made Quicksilver's bezel feel soft
  hs.timer.doAfter(0.5, function() c:delete() end)
end

-- panes: { { label, detail, key?, icons? = { hs.image… }, art? = fn(x, y, w)
-- → elements, selected?, pick? = fn } … }. With `linger` it is a notice that
-- leaves by itself; without, a picker: ←/→ or tab move, return or a click
-- picks, a pane's own key picks it outright, escape leaves.
local function bezel(panes, linger)
  -- one notice replacing another swaps in place: a knob spin is a run of
  -- notices, and a fade between each would flicker
  local swap = linger and q11Bezel ~= nil
  closeBezel(swap)
  local w, h = PAD * 2 + #panes * PANE + (#panes - 1) * GAP, PAD + PANE + FOOT
  local f = hs.screen.mainScreen():frame()
  local c = hs.canvas.new({
    x = f.x + (f.w - w) / 2 - EDGE, y = f.y + (f.h - h) * 0.4 - EDGE,
    w = w + EDGE * 2, h = h + EDGE * 2,
  })
  q11Bezel = c
  local sel = 1
  for i, p in ipairs(panes) do if p.selected then sel = i end end

  local function text(str, x, y, tw, size, color, font)
    return { type = "text", text = str, textSize = size, textColor = color,
      textFont = font or ".AppleSystemUIFont", textAlignment = "center",
      textLineBreak = "truncateTail",
      frame = { x = x, y = y, w = tw, h = size + 8 } }
  end
  local function draw()
    local els = { {
      type = "rectangle", action = "fill", fillColor = COBALT,
      frame = { x = EDGE, y = EDGE, w = w, h = h },
      roundedRectRadii = { xRadius = 22, yRadius = 22 },
      withShadow = true,
      shadow = { blurRadius = 28, color = { alpha = 0.45 }, offset = { h = -10, w = 0 } },
    } }
    for i, p in ipairs(panes) do
      local x, y = EDGE + PAD + (i - 1) * (PANE + GAP), EDGE + PAD
      els[#els + 1] = {
        id = "pane" .. i, type = "rectangle", action = "fill", trackMouseDown = true,
        fillColor = { white = 1, alpha = (i == sel and not linger) and 0.2 or 0.07 },
        frame = { x = x, y = y, w = PANE, h = PANE },
        roundedRectRadii = { xRadius = 14, yRadius = 14 },
      }
      -- up to three icons, fanned so each stays recognisable; one sits alone
      local icons = p.icons or {}
      local n = math.min(#icons, 3)
      local size, step = n == 1 and 108 or 84, 38
      local ix = x + (PANE - (size + (n - 1) * step)) / 2
      for k = 1, n do
        els[#els + 1] = { type = "image", image = icons[k],
          frame = { x = ix + (k - 1) * step, y = y + 16 + (108 - size) / 2, w = size, h = size } }
      end
      for _, el in ipairs(p.art and p.art(x, y, PANE) or {}) do els[#els + 1] = el end
      if p.key then
        els[#els + 1] = text(p.key:upper(), x + 8, y + 6, 20, 12, YELLOW, ".AppleSystemUIFontBold")
      end
      els[#els + 1] = text(p.label, x + 8, y + PANE - 38, PANE - 16, 16, FG,
        ".AppleSystemUIFontMedium")
    end
    local foot = panes[sel].detail
    if foot then
      els[#els + 1] = text(foot, EDGE + PAD, EDGE + PAD + PANE + 6, w - PAD * 2, 12, MUTED)
    end
    c:replaceElements(els)
  end
  draw()
  c:level(hs.canvas.windowLevels.modalPanel)
  c:behavior({ "canJoinAllSpaces", "transient" })
  c:show(swap and 0 or 0.16)
  if linger then
    hs.timer.doAfter(linger, function() if q11Bezel == c then closeBezel() end end)
    return
  end

  local function pick(i)
    closeBezel()
    if panes[i].pick then panes[i].pick() end
  end
  local function move(step)
    return function() sel = (sel - 1 + step) % #panes + 1; draw() end
  end
  c:mouseCallback(function(_, _, id)
    local i = tonumber(tostring(id):match("^pane(%d+)$"))
    if i then pick(i) end
  end)
  local keys = hs.hotkey.modal.new()
  q11BezelKeys = keys
  keys:bind({}, "right", move(1), nil, move(1))
  keys:bind({}, "tab", move(1))
  keys:bind({}, "left", move(-1), nil, move(-1))
  keys:bind({ "shift" }, "tab", move(-1))
  keys:bind({}, "return", function() pick(sel) end)
  keys:bind({}, "escape", closeBezel)
  for i, p in ipairs(panes) do
    if p.key then keys:bind({}, p.key, function() pick(i) end) end
  end
  keys:enter()
end

-- Muting is a flag the gesture callback reads, not a tap that gets stopped:
-- q11Health re-arms the taps every 30s regardless, so a stopped one would come
-- back by itself mid-game. Seeded from the current app so a reload while the
-- game is already frontmost starts muted, not on the next app switch.
local function muteApp(app)
  return app ~= nil and MUTE_APPS[app:bundleID()] == true
end
q11Muted = muteApp(hs.application.frontmostApplication())
q11AppWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated then q11Muted = muteApp(app) end
end):start()

-- ── polling-rate menubar ────────────────────────────────────────────────
-- The board keeps separate polling rates for cable and 2.4G and only the
-- wireless one costs battery, so this switches that one. keylight.py owns the
-- HID side — same shell-out discipline as rcmd below, and it keeps one writer
-- for the keyboard rather than a second implementation in Lua.
local POLL_RATES = { 8000, 4000, 2000, 1000, 500, 250, 125 }

local function keylight(args, done)
  local argv = { "run", REPO .. "/backlight/keylight.py" }
  for _, v in ipairs(args) do argv[#argv + 1] = v end
  hs.task.new(UV, function(code, out) done(code == 0 and out or nil) end, argv):start()
end

q11PollBar = hs.menubar.new() -- global: a local would be GC'd and vanish
-- A drawn bolt, not a Unicode glyph: as a template image the menu bar tints it
-- itself, so it is right on a light bar, a dark one and when highlighted.
q11PollBar:setIcon(hs.canvas.new({ x = 0, y = 0, w = 16, h = 16 }):appendElements({
  type = "segments", closed = true, action = "fill", fillColor = { black = 1 },
  coordinates = {
    { x = 9.5, y = 0.5 }, { x = 3, y = 9 }, { x = 7.5, y = 9 },
    { x = 6, y = 15.5 }, { x = 13, y = 6.5 }, { x = 8.5, y = 6.5 },
  },
}):imageFromCanvas(), true)

-- Global, like q11SwipeReport: `hs -c 'q11PollRefresh()'` re-reads on demand
-- rather than waiting out the timer — which is what you want the moment the
-- title reads "?" and you are asking whether the keyboard or the code is at
-- fault.
function q11PollRefresh()
  if not q11PollBar then return end
  keylight({ "polling" }, function(out)
    -- rf=, not wired=: the cable rate is not what drains the battery.
    local hz = out and tonumber(out:match("rf=(%d+)"))
    if not q11PollBar then return end
    q11PollBar:setTitle(hz
      and (hz >= 1000 and math.floor(hz / 1000) .. "K" or tostring(hz))
      or "?") -- keyboard asleep or Launcher holding the interface
    local menu = {}
    for _, r in ipairs(POLL_RATES) do
      menu[#menu + 1] = {
        title = r .. " Hz",
        checked = hz == r,
        fn = function()
          keylight({ "polling", "2.4g", tostring(r) }, function() q11PollRefresh() end)
        end,
      }
    end
    q11PollBar:setMenu(menu)
  end)
end
q11PollRefresh()
-- The Launcher can change the rate behind our back; re-read occasionally so a
-- stale title does not lie. Ten minutes, because spawning uv is not free and
-- this value changes about never.
q11PollTimer = hs.timer.doEvery(600, q11PollRefresh)

-- The receiver gets unplugged often on this machine, and the ten-minute timer
-- alone would leave the title wrong for most of every reconnect. Presence is
-- polled on the health tick below rather than watched: hs.usb.watcher never
-- delivered a single event for this dongle, which lives in a Thunderbolt dock
-- and so hangs off a different USB controller than a root-port device. A table
-- scan every 30s is duller than debugging IOKit notification delivery, and it
-- does not care where the dongle is plugged in.
local RECEIVER_VID = 0x3434 -- Keychron; the dongle is 0xd028, the board 0x12b2
local function receiverPresent()
  for _, d in ipairs(hs.usb.attachedDevices() or {}) do
    if d.vendorID == RECEIVER_VID then return true end
  end
  return false
end
q11ReceiverSeen = receiverPresent()

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

-- Show every stage and activate the one picked. rcmd's own stage overview is
-- bound to holding `caps` and has no CLI verb at all (`rcmd osd` only does the
-- search surfaces: app, window, hide), and a hold-to-show OSD does not map onto
-- a momentary tap anyway — so build the list from `stage list --json` and make
-- it pick rather than merely display.
local function showStages()
  -- global: an unreferenced task can be collected before its callback runs,
  -- and then the tap does nothing with nothing to see
  q11StageTask = hs.task.new(RCMD, function(code, out)
    if code ~= 0 then return end
    local ok, data = pcall(hs.json.decode, out)
    if not ok or type(data) ~= "table" or type(data.stages) ~= "table" then return end
    local panes = {}
    for _, s in ipairs(data.stages) do
      local icons, apps, seen = {}, {}, {}
      for _, item in ipairs(s.items or {}) do
        -- one icon per app: two Zen windows are still one thing to recognise
        if item.bundleID and not seen[item.bundleID] then
          seen[item.bundleID] = true
          icons[#icons + 1] = hs.image.imageFromAppBundle(item.bundleID)
          apps[#apps + 1] = item.appName or item.bundleID
        end
      end
      local count = #(s.items or {})
      panes[#panes + 1] = {
        label = s.name or tostring(s.key), key = s.key, icons = icons,
        selected = s.isActive,
        detail = ("%s · %d window%s%s"):format(table.concat(apps, ", "), count,
          count == 1 and "" or "s", s.isActive and " · active" or ""),
        pick = function() rcmd("stage", "activate", s.key) end,
      }
    end
    if #panes == 0 then return end
    bezel(panes)
  end, { "stage", "list", "--json" })
  q11StageTask:start()
end
q11ShowStages = showStages -- global for `hs -c`, to open the picker without a trackpad

local GESTURES = {
  -- cmd + four: window placement. `place` takes halves, corners, thirds and
  -- quarters too — see `rcmd help window place` before adding more.
  { fingers = 4, dir = "left",  cmd = true, action = function() rcmd("window", "place", "left-half") end },
  { fingers = 4, dir = "right", cmd = true, action = function() rcmd("window", "place", "right-half") end },
  { fingers = 4, dir = "up",    cmd = true, action = function() rcmd("window", "place", "maximized") end },
  { fingers = 4, dir = "down",  cmd = true, action = function() rcmd("window", "place", "center") end },
  -- four bare, tapped: pick a stage. A four-finger *swipe* is an awkward motion
  -- and was dropped; a physical four-finger click reads as a tap here too,
  -- since the fingers are down, still, and briefly. Deliberately no `stage
  -- close` anywhere — stageCloseAction is `close`, so it shuts real windows and
  -- any agent inside them, which no stray gesture should be able to do.
  { fingers = 4, dir = "tap",   cmd = false, action = showStages },
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
-- How long the scroll swallow outlives the last full-count touch: long enough
-- to eat the momentum handoff, short enough that a lifted hand gets scrolling
-- back straight away.
local SCROLL_HOLD = 0.25
-- A tap is the absence of a swipe: fingers down and up again quickly without
-- travelling. TAP_TRAVEL must stay well under SWIPE_MIN, or a swipe that dies
-- early reads as a tap; the gap between them is a dead zone on purpose.
-- TAP_HOLD keeps resting four fingers on the trackpad from counting.
local TAP_TRAVEL = 0.02
local TAP_HOLD = 0.4

-- Pure, like swipeDir, so both are checkable without a trackpad.
local function isTap(travel, held)
  return travel <= TAP_TRAVEL and held <= TAP_HOLD
end

-- Pure too. Nanoseconds, because that is what hs.timer.absoluteTime deals in.
local function scrollSwallowed(now, tFull)
  return (now - tFull) / 1e9 <= SCROLL_HOLD
end

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

  -- taps, and the things that must not read as one
  local taps = {
    { 0, 0.10, true },       -- dead still, quick
    { 0.015, 0.30, true },   -- slight wobble, still a tap
    { 0.05, 0.10, false },   -- travelled: a swipe that died in the dead zone
    { 0.01, 1.20, false },   -- barely moved but held: resting, not tapping
    { 0.20, 0.10, false },   -- a real swipe
  }
  for _, c in ipairs(taps) do
    local got = isTap(c[1], c[2])
    assert(got == c[3], ("isTap(%s,%s)=%s want %s")
      :format(c[1], c[2], tostring(got), tostring(c[3])))
  end
  -- the scroll swallow, which must never outlive the fingers by more than
  -- SCROLL_HOLD however long the scrolling itself runs on
  local T, S = 1e12, 1e9 -- an arbitrary now, and one second in those units
  local holds = {
    { 0,    true },   -- fingers still down
    { 0.10, true },   -- momentum handoff, still ours to eat
    { 0.50, false },  -- long past: the app gets its scrolling back
    { 5.0,  false },  -- where a swallow that fed itself used to live
  }
  for _, c in ipairs(holds) do
    local got = scrollSwallowed(T + c[1] * S, T)
    assert(got == c[2], ("scrollSwallowed(+%.2fs)=%s want %s")
      :format(c[1], tostring(got), tostring(c[2])))
  end
  return "selftest ok (swipe + tap + swallow)"
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
-- A ring buffer, not print(). hs.ipc (required at the top of this file)
-- permanently replaces the global print, and outside an active `hs -c` command
-- that replacement indexes a dead connection and throws — so a print() in here
-- would abort the callback mid-swipe, not merely fail to show up anywhere.
q11SwipeDebug = false
q11SwipeLog = {}

function q11SwipeReport()
  return #q11SwipeLog == 0 and "no swipes recorded" or table.concat(q11SwipeLog, "\n")
end

q11Swipe = nil      -- in-flight gesture; global so a reload can't strand it
q11SwipeTimer = nil -- reused, not recreated: this runs thousands of times a swipe

-- End of gesture. A swipe has already fired by now — mid-motion, the moment it
-- crossed the threshold. A tap can only be recognised here, by having failed to
-- become a swipe before the fingers left.
local function finalizeSwipe()
  local s = q11Swipe
  q11Swipe, q11SwipeTimer = nil, nil
  if not s then return end
  local dx, dy = s.x - s.x0, s.y - s.y0
  local travel = math.max(math.abs(dx), math.abs(dy))
  -- tLast, not "now": finalize runs SWIPE_IDLE after the last touch, and
  -- charging that idle to the hold would silently shorten every tap window.
  local held = (s.tLast - s.t0) / 1e9
  local tapped = not s.fired and isTap(travel, held)
  if tapped then runGesture(s.n, s.cmd, "tap") end
  if q11SwipeDebug then
    q11SwipeLog[#q11SwipeLog + 1] =
      ("fingers=%d dx=%+.4f dy=%+.4f held=%.2fs cmd=%s -> %s")
        :format(s.n, dx, dy, held, tostring(s.cmd),
          s.fired and "swipe" or (tapped and "tap" or "nothing"))
    if #q11SwipeLog > 20 then table.remove(q11SwipeLog, 1) end
  end
end

local SCROLL = hs.eventtap.event.types.scrollWheel

q11GestureTap = hs.eventtap.new({ hs.eventtap.event.types.gesture, SCROLL }, function(e)
  -- Stand down entirely for a muted app: no swipe fired, and — the point — no
  -- scroll swallowed, so the game keeps every event the trackpad sends.
  if q11Muted then return false end
  -- The fingers driving a swipe also drive a scroll, on a separate event
  -- stream: without swallowing it the window underneath scrolls for as long as
  -- the swipe takes to recognise. Gated on `armed`, so this can only ever
  -- suppress a finger count and modifier already bound to a gesture — plain
  -- two-finger scrolling never reaches the branch.
  if e:getType() == SCROLL then
    local s = q11Swipe
    if not (s and s.armed and s.tFull) then return false end
    -- Hold the window open past the last touch, or momentum scrolling lands in
    -- the app right after the gesture is recognised. Measured from the last
    -- full-count touch and deliberately not refreshed here: extending the
    -- window from inside the swallow made it feed itself, so scrolling stayed
    -- suppressed for as long as the scrolling continued.
    return scrollSwallowed(hs.timer.absoluteTime(), s.tFull)
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
    s = { n = n, x0 = cx, y0 = cy, x = cx, y = cy, cmd = false, armed = false,
          t0 = hs.timer.absoluteTime() }
    q11Swipe = s
  elseif n == s.n then
    s.x, s.y = cx, cy -- fingers lifting (n < s.n) must not drag the endpoint
  end
  local now = hs.timer.absoluteTime()
  s.tLast = now -- how long the fingers were actually down
  -- Last moment the full count was on the pad. tLast keeps advancing as the
  -- hand lifts away — a partial lift to two fingers still refreshes it — so
  -- keying the swallow off tLast left ordinary two-finger scrolling dead after
  -- any three- or four-finger contact.
  if n == s.n then s.tFull = now end
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
  if q11GestureTap then q11GestureTap:stop() end
  if q11Watcher then q11Watcher:stop() end
  if q11AppWatcher then q11AppWatcher:stop() end
  if q11Health then q11Health:stop() end
  if q11PollTimer then q11PollTimer:stop() end
  if q11PollBar then q11PollBar:delete() end
end

-- macOS silently disables event taps and isEnabled() keeps reporting true, so a
-- watchdog that checks it never fires. Re-arm unconditionally; costs microseconds.
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

q11Health = hs.timer.doEvery(30, function()
  if q11CopyTap then q11CopyTap:stop():start() end
  if q11GestureTap then
    q11GestureTap:stop():start()
    -- a re-arm mid-swipe would leave the next event mis-anchored
    if q11SwipeTimer then q11SwipeTimer:stop() end
    q11Swipe, q11SwipeTimer = nil, nil
  end
  -- Only spawns uv when presence actually flips, so the steady state costs a
  -- table scan. The HID interfaces trail the USB device on plug-in, hence the
  -- delay before asking the keyboard anything.
  local present = receiverPresent()
  if present ~= q11ReceiverSeen then
    q11ReceiverSeen = present
    hs.timer.doAfter(present and 1.5 or 0, q11PollRefresh)
  end
end)

q11ShowBezel = bezel -- global for `hs -c`, to look at a bezel without a trackpad
-- Storykeep's meeting watcher lives in casey-claude-setup, which no other
-- host that runs this router has. Guarded so a missing repo costs a console
-- line instead of the tail of this file.
local ok, meetings = pcall(dofile, os.getenv("HOME") .. "/dev/casey-claude-setup/companion/companions/storykeep/orchestration/meetings.lua")
storykeepMeetings = ok and meetings or nil -- global on purpose: it outlives this file
if not ok then print("storykeep meetings not loaded: " .. tostring(meetings)) end
