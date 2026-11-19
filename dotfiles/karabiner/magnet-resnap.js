// magnet-resnap.js save FILE | apply FILE: used by menubar-toggle.sh (Hyper+7)
// to re-fit snapped windows when Magnet's gaps change, like refit_snapped() in
// hypr/hyprland.lua. Magnet only applies its gaps when it snaps a window, so:
//
//   save   notes which Magnet command (left half, maximize, ...) each window
//          on screen is sitting in, give or take the gaps, before anything
//          changes. Back to front, so the stacking order mostly survives.
//   apply  raises each of those windows and presses that command's shortcut,
//          so Magnet snaps it again with its new gaps, then puts the focus
//          back on the window that had it.
//
// Only commands with a keyboard shortcut set in Magnet can be redone, and only
// windows on the current Space (minimized and full-screen ones are left be).
// Pressing the shortcuts needs Accessibility for karabiner_console_user_server.
ObjC.import('AppKit')
ObjC.import('CoreGraphics')

// how far (px) a window's edges can be from a command's grid rect and still
// count as snapped there: more than Magnet's gap, much less than a grid cell
const TOLERANCE = 40

function run([mode, file]) {
  if (mode === 'save') save(file)
  else if (mode === 'apply') apply(file)
  else throw new Error('usage: magnet-resnap.js save|apply FILE')
}

// Magnet's commands with a shortcut: {grid: [[x, y], [w, h]], key, mods} each,
// for landscape screens (a 24x12 grid) and portrait ones (12x24)
function commands() {
  const prefs = $.NSUserDefaults.alloc.initWithSuiteName('com.crowdcafe.windowmagnet')
  const read = (key) => {
    const data = prefs.dataForKey(key)
    if (!data || data.isNil()) return []
    return JSON.parse($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js)
  }
  const usable = (list) =>
    list.flatMap((c) => {
      const segs = (c.targetArea && c.targetArea.area && c.targetArea.area.segments) || []
      const ks = c.keyboardShortcut || {}
      if (c.specialType || segs.length !== 1 || !ks.enabled || !ks.shortcut) return []
      return [{ grid: segs[0].frame, key: ks.shortcut.carbonKeyCode, mods: ks.shortcut.carbonModifiers }]
    })
  return { horizontal: usable(read('horizontalCommands')), vertical: usable(read('verticalCommands')) }
}

// screens' usable areas in top-left-origin coordinates (like window bounds)
function screens() {
  const all = ObjC.unwrap($.NSScreen.screens)
  const primaryHeight = all[0].frame.size.height
  return all.map((s) => {
    const f = s.visibleFrame
    const full = s.frame
    return {
      x: f.origin.x,
      y: primaryHeight - (f.origin.y + f.size.height),
      w: f.size.width,
      h: f.size.height,
      full: { x: full.origin.x, y: primaryHeight - (full.origin.y + full.size.height), w: full.size.width, h: full.size.height },
    }
  })
}

// regular app windows on screen, front to back: {pid, x, y, w, h}
function windows() {
  const opts = $.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements
  const list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(opts, $.kCGNullWindowID))) || []
  return list
    .filter((w) => w.kCGWindowLayer === 0 && w.kCGWindowAlpha > 0)
    .map((w) => ({ pid: w.kCGWindowOwnerPID, x: w.kCGWindowBounds.X, y: w.kCGWindowBounds.Y, w: w.kCGWindowBounds.Width, h: w.kCGWindowBounds.Height }))
}

// the command whose grid rect the window fits best (within TOLERANCE), if any
function snappedCommand(win, cmds, scrs) {
  const cx = win.x + win.w / 2
  const cy = win.y + win.h / 2
  const s = scrs.find((s) => cx >= s.full.x && cx < s.full.x + s.full.w && cy >= s.full.y && cy < s.full.y + s.full.h)
  if (!s) return null
  const portrait = s.h > s.w
  const [cols, rows] = portrait ? [12, 24] : [24, 12]
  let best = null
  let bestErr = TOLERANCE
  for (const c of portrait ? cmds.vertical : cmds.horizontal) {
    const [[gx, gy], [gw, gh]] = c.grid
    const left = s.x + (gx / cols) * s.w
    const top = s.y + (gy / rows) * s.h
    const right = s.x + ((gx + gw) / cols) * s.w
    const bottom = s.y + ((gy + gh) / rows) * s.h
    const err = Math.max(
      Math.abs(win.x - left),
      Math.abs(win.y - top),
      Math.abs(win.x + win.w - right),
      Math.abs(win.y + win.h - bottom),
    )
    if (err < bestErr) {
      best = c
      bestErr = err
    }
  }
  return best
}

function save(file) {
  const cmds = commands()
  const scrs = screens()
  const snapped = windows()
    .map((win) => ({ win, cmd: snappedCommand(win, cmds, scrs) }))
    .filter((s) => s.cmd)
    .reverse() // back to front
  const front = $.NSWorkspace.sharedWorkspace.frontmostApplication
  const state = { front: front.isNil() ? null : front.processIdentifier, snapped }
  $(JSON.stringify(state)).writeToFileAtomicallyEncodingError(file, true, $.NSUTF8StringEncoding, null)
}

// the System Events window of `pid` at the bounds saved for it
function axWindow(se, win) {
  const procs = se.processes.whose({ unixId: win.pid })
  if (!procs.length) return null
  for (const w of procs[0].windows()) {
    try {
      const [x, y] = w.position()
      const [width, height] = w.size()
      if (Math.abs(x - win.x) <= 4 && Math.abs(y - win.y) <= 4 && Math.abs(width - win.w) <= 4 && Math.abs(height - win.h) <= 4) {
        return { proc: procs[0], w }
      }
    } catch (e) {}
  }
  return null
}

function using(mods) {
  const out = []
  if (mods & 256) out.push('command down')
  if (mods & 512) out.push('shift down')
  if (mods & 2048) out.push('option down')
  if (mods & 4096) out.push('control down')
  return out
}

function apply(file) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(file, $.NSUTF8StringEncoding, null)
  if (text.isNil()) return
  const state = JSON.parse(text.js)
  const se = Application('System Events')
  let frontWin = null
  for (const { win, cmd } of state.snapped) {
    const found = axWindow(se, win)
    if (!found) continue
    found.proc.frontmost = true
    found.w.actions.byName('AXRaise').perform()
    delay(0.15)
    se.keyCode(cmd.key, { using: using(cmd.mods) })
    delay(0.15)
    if (win.pid === state.front) frontWin = found
  }
  // the focused window was the front one of its app: raise it again last
  if (state.front !== null) {
    const app = $.NSRunningApplication.runningApplicationWithProcessIdentifier(state.front)
    if (!app.isNil()) app.activateWithOptions(0)
    if (frontWin) frontWin.w.actions.byName('AXRaise').perform()
  }
}
