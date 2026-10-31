-- Hyprland (ThinkPad), with Noctalia as the bar/launcher/notifications.
-- Pick "Hyprland (uwsm-managed)" on the GDM login screen (gear icon), not plain
-- "Hyprland": that one never starts the portal, so apps miss dark mode.
--
-- Keys match GNOME and the Mac. keyd (hosts/nixos) already handles, everywhere:
--   Caps Lock tap = Esc, hold = Meh (Ctrl+Super+Alt)
--   Alt-labeled key = Cmd (sends Ctrl), Ctrl-labeled key sends Alt
--   Cmd+←/→ = Home/End, Super+←/→ = word jumps, Cmd+Tab sends Alt+Tab
-- So below, "Cmd" is CTRL.
-- Docs: https://wiki.hypr.land/Configuring/Start/

local CMD = "CTRL"
local MEH = "CTRL + SUPER + ALT"
local terminal = "ghostty"

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	-- 1x like GNOME. "auto" picked 1.5x on the 1920x1200 panel (everything
	-- looked huge). Try 1.25 if text is too small.
	scale = 1,
})

-- The 4K ASUS monitor: 1.25x (3072x1728 worth of space). Matched by name, so
-- it gets this on any port.
hl.monitor({
	output = "desc:ASUSTek COMPUTER INC XG32UCWG",
	mode = "preferred",
	position = "auto",
	scale = 1.25,
})

-- Display settings app (nwg-displays) saves here, per machine (gitignored).
-- Loaded after the defaults above so its settings win.
local monitors_file = os.getenv("HOME") .. "/.config/hypr/monitors.lua"
if io.open(monitors_file) then
	local ok, err = pcall(dofile, monitors_file)
	if not ok then
		print("monitors.lua: " .. tostring(err))
	end
end

-- Lid closed with another monitor plugged in: turn the laptop screen off, so
-- its workspaces move to the other monitor and the cursor can't wander onto
-- it. Opening the lid turns it back on. (With nothing else plugged in, closing
-- the lid suspends as usual and the screen stays on.) Also checked on config
-- reloads and when a monitor is plugged in, since reloads re-apply the rules
-- above.
local LAPTOP_SCREEN = "eDP-1"

local function lid_closed()
	local f = io.open("/proc/acpi/button/lid/LID/state", "r")
	if not f then
		return false
	end
	local state = f:read("*a")
	f:close()
	return state:find("closed", 1, true) ~= nil
end

local function other_monitor()
	for _, m in ipairs(hl.get_monitors() or {}) do
		if m.name ~= LAPTOP_SCREEN then
			return true
		end
	end
	return false
end

local function laptop_screen(on)
	if on then
		-- disabled = false is needed: the rule otherwise keeps `disabled` from before
		hl.monitor({ output = LAPTOP_SCREEN, mode = "preferred", position = "auto", scale = 1, disabled = false })
	elseif other_monitor() then
		hl.monitor({ output = LAPTOP_SCREEN, disabled = true })
	end
end

hl.bind("switch:on:Lid Switch", function()
	laptop_screen(false)
end, { locked = true })
hl.bind("switch:off:Lid Switch", function()
	laptop_screen(true)
end, { locked = true })
hl.on("monitor.added", function()
	if lid_closed() then
		laptop_screen(false)
	end
	-- the new monitor's menu bar fade (menubar-wallpaper.sh); after a moment,
	-- once Noctalia has its wallpaper and bar up
	hl.exec_cmd("sleep 3; bash " .. os.getenv("HOME") .. "/.config/hypr/menubar-wallpaper.sh")
end)
laptop_screen(not lid_closed())

hl.on("hyprland.start", function()
	hl.exec_cmd("noctalia")
	-- The dock starts hidden at log-in (Noctalia remembers a shown one); hide
	-- it once Noctalia is up. The launcher's Toggle Dock entry shows it.
	hl.exec_cmd("for i in $(seq 40); do noctalia msg dock-hide && break; sleep 0.5; done")
	-- Game mode (bar button) starts off at log-in
	hl.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/gamemode.sh off")
	-- Square GTK window corners here only; GNOME removes these links at log-in
	-- (see home.nix).
	hl.exec_cmd("for v in 3 4; do ln -sf ~/.config/hypr/gtk.css ~/.config/gtk-$v.0/hyprland.css; done")
	-- Noctalia's light / dark mode follows GNOME's (the one apps use)
	hl.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/follow-appearance.sh")
	-- the menu bar's blur fading into the wallpaper (menubar-wallpaper.sh)
	hl.exec_cmd("bash " .. os.getenv("HOME") .. "/.config/hypr/menubar-wallpaper.sh")
end)

-- Same cursor as GNOME (Adwaita, 24px). Without a theme set, Hyprland and each
-- app fell back to different default cursors.
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Adwaita")
hl.env("HYPRCURSOR_SIZE", "24")

-- Steam is an X11 app, and Hyprland stretched it to the 4K monitor's 1.25x
-- scale, which made its text blurry. Xwayland apps now draw at full
-- resolution (force_zero_scaling, below) and Steam scales its own UI instead,
-- from Xft.dpi, set to the focused monitor's scale when Steam starts
-- (programs.steam, hosts/nixos).

-- Animations: quick and Mac-like, about half the length of Hyprland's
-- defaults. Speed is in tenths of a second (1.5 = 150 ms). Windows pop in
-- with a fast spring, workspaces switch instantly, menus/launcher fade.
hl.curve("snap", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1 } } }) -- fast start, soft landing
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("springy", { type = "spring", mass = 1, stiffness = 400, dampening = 32 }) -- quick, barely any bounce

hl.animation({ leaf = "global", enabled = true, speed = 3, bezier = "snap" })
hl.animation({ leaf = "windows", enabled = true, speed = 2.5, spring = "springy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, spring = "springy", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "linear", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, spring = "springy" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "snap" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1, bezier = "linear" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1, bezier = "linear", style = "fade" })
-- switching workspaces is instant: no slide (Cmd+H's special workspace, below, still slides)
hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "border", enabled = true, speed = 3, bezier = "easeOutQuint" })

hl.config({
	general = {
		gaps_in = 12, -- (zen mode, Meh+0, sets these and the border to 0)
		gaps_out = { top = 8, right = 24, bottom = 24, left = 24 }, -- less under the menu bar (BAR_GAP, below)
		border_size = 1, -- thin, like the Mac's (colors: BORDER COLORS, below)
		layout = "dwindle",
		resize_on_border = true, -- drag a window's edge to resize it, like the Mac
	},
	decoration = {
		rounding = 8, -- (zen mode, Meh+0, sets it to 0: square corners)
		-- frosted glass like the Mac's menu bar and dock (and behind Ghostty's
		-- translucent background): a soft, Gaussian-looking blur about the Mac's
		-- width (radius ~size * 2^passes: 5 and 3 is ~40px; 8 and 4 smeared
		-- ~128px into dark mush), with a touch of color and grain
		blur = {
			size = 1,
			passes = 2,
			vibrancy = 0.2,
			noise = 0.08,
		},
		-- zen mode's black dim over the wallpaper (update_zen_dim, below): as dark as
		-- Ghostty's own background (background-opacity 0.70), which it stands in for
		dim_around = 0.7,
	},
	animations = {
		enabled = true, -- short and snappy (curves and speeds below)
	},
	dwindle = {
		preserve_split = true,
	},
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
	xwayland = {
		force_zero_scaling = true, -- sharp X11 apps (Steam) on the 1.25x monitor
	},
	input = {
		kb_layout = "us",
		-- same fast key repeat as GNOME and the Mac (225 ms delay, 30 ms interval)
		repeat_delay = 225,
		repeat_rate = 33,
		follow_mouse = 1,
		touchpad = {
			natural_scroll = true,
		},
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

------------------
---- MAC KEYS ----
------------------

-- Cmd+Space: Noctalia's launcher (Spotlight/Raycast)
hl.bind(CMD .. " + space", hl.dsp.exec_cmd("noctalia msg panel-toggle launcher"))
-- Cmd+Tab: my app switcher (dotfiles/noctalia/plugins/app-switcher): one tile
-- per app in a 4-column grid. Hold Cmd and use h/j/k/l (or Tab, arrows, Cmd+Tab
-- again) to move; let go of Cmd to switch, Esc cancels. A panel only gets
-- messages while it's open, so the first press opens it and later ones tell it
-- to move to the next app. keyd turns Cmd+Tab into Alt+Tab with Alt held until
-- Cmd is let go (and Cmd+h/j/k/l into Alt+h/j/k/l, hosts/nixos),
-- so the switcher sees Alt let go when Cmd is. (A release bind here didn't
-- fire: Hyprland skips it when Tab was pressed in between.) The Cmd (Ctrl)
-- forms catch Cmd+Tab arriving as-is or with both held. Shift+Tab isn't bound
-- here, so it reaches the open switcher.
local SWITCHER = "kody/app-switcher:switcher"
for _, mods in ipairs({ "ALT", CMD, CMD .. " + ALT" }) do
	hl.bind(
		mods .. " + Tab",
		hl.dsp.exec_cmd(
			"noctalia msg plugin " .. SWITCHER .. " all next >/dev/null 2>&1 || noctalia msg panel-open " .. SWITCHER
		)
	)
end

-- Cmd+` / Cmd+Shift+`: next/previous window of the focused app, like the Mac.
local function cycle_app_windows(step)
	return function()
		local active = hl.get_active_window()
		if not active then
			return
		end
		local wins = {}
		for _, w in ipairs(hl.get_windows({ class = active.class }) or {}) do
			-- only this app, only windows you can see (skips hidden ones, Cmd+H)
			if
				w.class == active.class
				and w.mapped
				and not w.hidden
				and w.workspace
				and w.workspace.id == active.workspace.id
			then
				wins[#wins + 1] = w
			end
		end
		if #wins < 2 then
			return
		end
		table.sort(wins, function(a, b)
			return a.stable_id < b.stable_id
		end)
		for i, w in ipairs(wins) do
			if w.address == active.address then
				local nxt = wins[(i - 1 + step) % #wins + 1]
				hl.dispatch(hl.dsp.focus({ window = "address:" .. nxt.address }))
				hl.dispatch(hl.dsp.window.bring_to_top())
				return
			end
		end
	end
end
hl.bind(CMD .. " + grave", cycle_app_windows(1))
hl.bind(CMD .. " + SHIFT + grave", cycle_app_windows(-1))
-- Cmd+H: hide into a scratch workspace; Meh+H... is tiling, so unhide with Cmd+Shift+H
-- follow = false: without it the hidden workspace opens on screen, so the
-- window looked like it never hid.
-- Cmd+Shift+4: screenshot of a region (saved to ~/Pictures/Screenshots and copied), like the Mac
hl.bind(CMD .. " + SHIFT + 4", hl.dsp.exec_cmd("noctalia msg screenshot-region"))
hl.bind(CMD .. " + H", hl.dsp.window.move({ workspace = "special:hidden", follow = false }))
hl.bind(CMD .. " + SHIFT + H", hl.dsp.workspace.toggle_special("hidden"))

-- An app hidden with Cmd+H that asks to come forward (a timer or alarm going
-- off, a notification clicked): bring it back to the current workspace and
-- focus it.
hl.on("window.urgent", function(w)
	if not (w and w.address and w.workspace and w.workspace.name == "special:hidden") then
		return
	end
	local ws = hl.get_active_workspace()
	local sel = "address:" .. w.address
	hl.dispatch(hl.dsp.window.move({ workspace = ws and ws.id or 1, window = sel }))
	hl.dispatch(hl.dsp.focus({ window = sel }))
	hl.dispatch(hl.dsp.window.bring_to_top())
end)
-- Cmd+Q force-kills the focused app (SIGKILL, no prompts, no "minimize to
-- tray"): its whole process tree, via kill-app.sh next to this file.
-- Cmd+W / Cmd+N are left to apps (they see Ctrl+W/N).
-- Apps in CLOSE_ONLY just get their window closed (Steam keeps running in the
-- tray).
local KILL_APP = os.getenv("HOME") .. "/.config/hypr/kill-app.sh"
local CLOSE_ONLY = { steam = true }
hl.bind(CMD .. " + Q", function()
	local w = hl.get_active_window()
	if not w then
		return
	end
	if CLOSE_ONLY[(w.class or ""):lower()] then
		hl.dispatch(hl.dsp.window.close())
	elseif w.pid then
		hl.exec_cmd("bash " .. KILL_APP .. " " .. w.pid)
	end
end)
-- Claude: Cmd+0 toggles the sidebar (its Cmd+B), like the Mac's Karabiner
-- rule. Only bound while Claude is focused, so other apps keep their Cmd+0.
local CLAUDE = { ["com.anthropic.claude"] = true, claude = true }
local claude_sidebar = hl.bind(CMD .. " + 0", hl.dsp.send_shortcut({ mods = CMD, key = "B" }))
local function claude_focused(w)
	claude_sidebar:set_enabled(w ~= nil and CLAUDE[(w.class or ""):lower()] == true)
end
claude_focused(hl.get_active_window())
hl.on("window.active", claude_focused)
-- Ctrl+Cmd+Q: lock screen, like the Mac (the Ctrl-labeled key sends Alt).
hl.bind(CMD .. " + ALT + Q", hl.dsp.exec_cmd("noctalia msg session lock"))
-- Ctrl+Alt+Delete: Noctalia's session menu (log out, reboot, shut down, ...).
-- keyd swaps Ctrl and Alt, so the labeled keys still arrive as Ctrl+Alt.
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("noctalia msg panel-toggle session"))

------------------
---- WINDOWS  ----
------------------

-- Floating by default, like the Mac and GNOME. Meh+F tiles/floats one window.
-- (No Super+key binds: in Ghostty, Super is ⌥/Alt like the Mac, see home.nix.)
hl.window_rule({
	name = "float-everything",
	match = { class = ".*" },
	float = true,
})
hl.bind(MEH .. " + F", hl.dsp.window.float({ action = "toggle" }))

-- Noctalia's dock and panels (launcher, Cmd+Tab switcher, control
-- center...) are translucent (dotfiles/noctalia): blur what's behind them,
-- like the Mac, instead of showing it plainly. ignore_alpha: not the clear
-- parts around them (shadows, corners).
hl.layer_rule({
	name = "blur-noctalia",
	match = { namespace = "^noctalia-(dock|panel)" },
	blur = true,
	ignore_alpha = 0.1,
})

-- Magnet-style snapping, same keys as GNOME (tile@kody). Each rect is
-- { x, y, width, height } as fractions of the screen minus Noctalia's bar.
-- Noctalia's dock, hidden by default (the launcher's Toggle Dock entry
-- shows/hides it). Its space is kept free here rather than by Noctalia
-- (reserve_space): Noctalia only gives it back ~2s after hiding, so windows
-- lagged and toggling quickly lost track of them. Whether it's shown lives in
-- a file so it survives config reloads, and resets to hidden at log-in
-- (Noctalia's dock is hidden then too, see hyprland.start).
local DOCK_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-dock-shown"
local DOCK_SPACE = 74 -- px the dock takes at the bottom (its exclusive zone, plus its 6px gap above the edge)

local function dock_hidden()
	local f = io.open(DOCK_FILE, "r")
	if f then
		f:close()
	end
	return f == nil
end

local dock_space = dock_hidden() and 0 or DOCK_SPACE -- what's kept free right now (0 when hidden or zen)

-- Tile size, from the bar's tile-size button (toggle_tile_scale(), below):
-- normally snaps use the whole screen; narrow, they share a centered area
-- TILE_WIDTH_NARROW of its width and TILE_HEIGHT_NARROW of its height instead
-- (halves, maximize... all inside it), for a big monitor. Narrow = a flag
-- file, so it survives config reloads and resets at log-in, like the dock.
local TILE_SCALE_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-tile-scale-narrow"
local TILE_WIDTH_NARROW, TILE_HEIGHT_NARROW = 0.75, 0.9
local tile_narrow = io.open(TILE_SCALE_FILE) ~= nil

local function work_area(monitor)
	local m = monitor or hl.get_active_monitor()
	local scale = m.scale or 1
	local w, h = m.width / scale, m.height / scale
	-- reserved space (the bar): {top, right, bottom, left} or named fields
	local r = type(m.reserved) == "table" and m.reserved or {}
	local top = r.top or r[1] or 0
	local right = r.right or r[2] or 0
	local bottom = r.bottom or r[3] or 0
	local left = r.left or r[4] or 0
	bottom = bottom + dock_space
	local aw, ah = w - left - right, h - top - bottom
	local sw, sh = tile_narrow and TILE_WIDTH_NARROW or 1, tile_narrow and TILE_HEIGHT_NARROW or 1
	local ix, iy = aw * (1 - sw) / 2, ah * (1 - sh) / 2
	return m.x + left + ix, m.y + top + iy, aw - 2 * ix, ah - 2 * iy
end

-- Padding (px) around snapped windows: GAP from the screen edges and GAP
-- between two windows side by side. Zen mode (Meh+0) sets it to 0.
local GAP_NORMAL = 24
local GAP = GAP_NORMAL
-- Under the menu bar the gap is smaller: the bar's own height already sets the
-- windows apart from it. (GAP again when the bar's hidden.)
local BAR_GAP = 8

local RECTS = {
	left_half = { 0, 0, 1 / 2, 1 },
	right_half = { 1 / 2, 0, 1 / 2, 1 },
	left_two_thirds = { 0, 0, 2 / 3, 1 },
	right_third = { 2 / 3, 0, 1 / 3, 1 },
	maximize = { 0, 0, 1, 1 },
	center = { 0.2, 0.2, 0.6, 0.6 }, -- centered, 60%
	-- quarters: Super+drag a window into a screen corner (below)
	top_left = { 0, 0, 1 / 2, 1 / 2 },
	top_right = { 1 / 2, 0, 1 / 2, 1 / 2 },
	bottom_left = { 0, 1 / 2, 1 / 2, 1 / 2 },
	bottom_right = { 1 / 2, 1 / 2, 1 / 2, 1 / 2 },
}

-- Where a window snapped to `rect` goes right now: x, y, width, height. On
-- `monitor`, or the focused one.
local function geometry(rect, monitor)
	local ax, ay, aw, ah = work_area(monitor)
	ax, ay, aw, ah = ax + GAP / 2, ay + GAP / 2, aw - GAP, ah - GAP
	if ay > (monitor or hl.get_active_monitor()).y + GAP / 2 then
		-- the bar's on top: start BAR_GAP below it, not GAP
		local d = math.max(GAP - BAR_GAP, 0)
		ay, ah = ay - d, ah + d
	end
	local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
	return math.floor(ax + x * aw + GAP / 2),
		math.floor(ay + y * ah + GAP / 2),
		math.floor(w * aw - GAP),
		math.floor(h * ah - GAP)
end

local function place(window, rect, monitor)
	local x, y, w, h = geometry(rect, monitor)
	hl.dispatch(hl.dsp.window.resize({ x = w, y = h, window = window }))
	hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = window }))
end

local function snap(rect)
	return function()
		local win = hl.get_active_window()
		if win then
			place("address:" .. win.address, rect)
		end
	end
end

-- The snap position a window is sitting in exactly (give or take 2px), if any.
local function snapped_rect(win)
	local at, size = win.at or {}, win.size or {}
	for _, rect in pairs(RECTS) do
		local x, y, w, h = geometry(rect)
		if
			math.abs((at.x or -1e9) - x) <= 2
			and math.abs((at.y or -1e9) - y) <= 2
			and math.abs((size.x or -1e9) - w) <= 2
			and math.abs((size.y or -1e9) - h) <= 2
		then
			return rect
		end
	end
end

-- Zen mode, Meh+0, per workspace: hides Noctalia's bar and dock, drops the
-- gaps, window borders and rounded corners (shadows stay), and dims the
-- wallpaper while Ghostty's background goes clear (below), on the workspace
-- you're on; Meh+0 there again brings them back. Switching workspaces switches zen with it. Snapped
-- windows are re-fitted to the new space. Which workspaces are zen lives in a
-- file (one name per line) so it survives config reloads (Hyprland reloads on
-- every save), and resets at log-in.
local ZEN_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-zen-workspaces"

local function zen_workspaces()
	local set = {}
	local f = io.open(ZEN_FILE, "r")
	if f then
		for name in f:lines() do
			set[name] = true
		end
		f:close()
	end
	return set
end

local function save_zen_workspaces(set)
	local f = io.open(ZEN_FILE, "w")
	if not f then
		return
	end
	for name in pairs(set) do
		f:write(name, "\n")
	end
	f:close()
end

-- The regular workspace on screen (a special one like Cmd+H's sits on top of it)
local function active_workspace_name()
	local ws = hl.get_active_workspace()
	return ws and ws.name
end

local zen_shown -- what's on screen right now (nil until the first apply)

-- Gaps, window borders and shadows can each be turned off everywhere, from
-- the launcher's Toggle Gaps / Borders / Shadows (home.nix). Off = a flag file, so
-- it survives config reloads and resets at log-in, like the dock.
local function flag_file(name)
	return (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-" .. name
end

local function flag_set(name)
	local f = io.open(flag_file(name), "r")
	if f then
		f:close()
	end
	return f ~= nil
end

-- gaps (and the snap padding, GAP) and borders: off in zen mode or when
-- toggled off. Shadows: only when toggled off. Corners: square in zen mode.
local function apply_decorations()
	local no_gaps = zen_shown or flag_set("gaps-off")
	GAP = no_gaps and 0 or GAP_NORMAL
	hl.config({
		general = {
			gaps_in = no_gaps and 0 or 12,
			gaps_out = no_gaps and 0 or {
				top = flag_set("bar-hidden") and GAP_NORMAL or BAR_GAP, -- less under the menu bar
				right = 24,
				bottom = 24,
				left = 24,
			},
			border_size = (zen_shown or flag_set("borders-off")) and 0 or 1,
		},
		decoration = {
			rounding = zen_shown and 0 or 8,
			shadow = { enabled = not flag_set("shadows-off") },
		},
	})
end

local function toggle_flag(name)
	if flag_set(name) then
		os.remove(flag_file(name))
	else
		local f = io.open(flag_file(name), "w")
		if f then
			f:close()
		end
	end
	apply_decorations()
end
-- `hyprctl eval 'toggle_borders()'` / `'toggle_shadows()'`
_G.toggle_borders = function()
	toggle_flag("borders-off")
end
_G.toggle_shadows = function()
	toggle_flag("shadows-off")
end

-- Zen mode's dimmed wallpaper: Ghostty's background goes clear and the
-- wallpaper is dimmed black instead (decoration.dim_around), so the text sits
-- on the dimmed wallpaper with no box around it and the window can stay
-- centered. A window with dim_around dims everything behind it, so the
-- bottom-most window on the workspace carries it: just the wallpaper is
-- behind that one, and every app stays undimmed. Windows are listed bottom to
-- top and focusing one raises it, so the dim moves along as you switch.
local zen_dimmed -- address of the window carrying the dim

local function bottom_window()
	local name = active_workspace_name()
	for _, w in ipairs(hl.get_windows() or {}) do
		local ws = w.workspace
		if w.mapped and ws and not ws.special and ws.name == name then
			return w.address
		end
	end
end

local function update_zen_dim()
	local want = zen_shown and bottom_window() or nil
	if want == zen_dimmed then
		return
	end
	zen_dimmed = want
	for _, w in ipairs(hl.get_windows() or {}) do
		pcall(hl.dispatch, hl.dsp.window.set_prop({
			window = "address:" .. w.address,
			prop = "dim_around",
			value = w.address == want and "true" or "unset",
		}))
	end
end
-- right away, and again just after, once a raised / opened / closed window has
-- settled into the list (before the next frame, so nothing flashes darker)
local function zen_dim_soon()
	update_zen_dim()
	hl.timer(update_zen_dim, { timeout = 1, type = "oneshot" })
end
for _, event in ipairs({ "window.open", "window.close", "window.destroy", "window.active", "window.move_to_workspace" }) do
	hl.on(event, zen_dim_soon)
end
-- Focus follows the mouse without raising; a click raises the window, with no
-- event of its own, so clicks check too (non_consuming: the click still goes
-- through to the window)
for _, button in ipairs({ "mouse:272", "mouse:273" }) do
	hl.bind(button, zen_dim_soon, { non_consuming = true, ignore_mods = true })
end

-- Ghostty's blur and shadow would outline the now-clear window
local zen_ghostty_rule = hl.window_rule({
	name = "zen-ghostty",
	match = { class = "^com\\.mitchellh\\.ghostty$" },
	enabled = false,
	no_blur = true,
	no_shadow = true,
})
-- Ghostty's clear background: an override its config includes
-- (dotfiles/ghostty/config), there only in zen mode. Ghostty reloads its
-- config on SIGUSR2. (App-wide: Ghostty windows on another monitor go clear too.)
local GHOSTTY_ZEN_FILE = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/ghostty-zen"

local function ghostty_clear(on)
	local f = io.open(GHOSTTY_ZEN_FILE, "r")
	if f then
		f:close()
	end
	if on == (f ~= nil) then
		return
	end
	if on then
		f = io.open(GHOSTTY_ZEN_FILE, "w")
		if not f then
			return
		end
		f:write("background-opacity = 0\n")
		f:close()
	else
		os.remove(GHOSTTY_ZEN_FILE)
	end
	hl.exec_cmd("pkill -USR2 ghostty")
end

-- show_bar = false at config load: Noctalia isn't up yet at log-in, and on a
-- reload the bar is already right.
local function apply_zen(on, show_bar)
	if on == zen_shown then
		return
	end
	zen_shown = on
	dock_space = (on or dock_hidden()) and 0 or DOCK_SPACE
	apply_decorations()
	update_zen_dim()
	zen_ghostty_rule:set_enabled(on)
	ghostty_clear(on)
	if show_bar ~= false then
		hl.exec_cmd(
			on and "noctalia msg bar-hide; noctalia msg dock-hide"
				or (flag_set("bar-hidden") and "true" or "noctalia msg bar-show")
					.. (dock_hidden() and "" or "; noctalia msg dock-show")
		)
	end
end

-- Runs change() (something that changes the free space: gaps, the bar, the
-- dock) and then re-fits the windows that were snapped before it, on
-- workspace `name` or, with no name, on every regular workspace. With `delay`
-- (ms), waits that long first, for Noctalia to hide/show the bar.
local function refit_snapped(change, name, delay)
	-- Note which windows are snapped before anything moves.
	local resnap = {}
	for _, win in ipairs(hl.get_windows() or {}) do
		local ws = win.workspace
		local rect = ws and not ws.special and (not name or ws.name == name) and snapped_rect(win)
		if rect then
			resnap[#resnap + 1] = { "address:" .. win.address, rect }
		end
	end

	change()

	local function refit()
		for _, item in ipairs(resnap) do
			place(item[1], item[2])
		end
	end
	if delay then
		hl.timer(refit, { timeout = delay, type = "oneshot" })
	else
		refit()
	end
end

-- `hyprctl eval 'toggle_gaps()'`: snapped windows are re-fitted to the new gaps
_G.toggle_gaps = function()
	refit_snapped(function()
		toggle_flag("gaps-off")
	end)
end

-- `hyprctl eval 'toggle_bar()'`: show/hide Noctalia's bar (the menu bar), on
-- top of zen mode, which hides it anyway. Snapped windows are re-fitted once
-- Noctalia has given back / taken its space.
_G.toggle_bar = function()
	refit_snapped(function()
		toggle_flag("bar-hidden")
		if not zen_shown then
			hl.exec_cmd("noctalia msg " .. (flag_set("bar-hidden") and "bar-hide" or "bar-show"))
		end
	end, nil, 300)
end

local function toggle_zen()
	local name = active_workspace_name()
	if not name then
		return
	end
	refit_snapped(function()
		local set = zen_workspaces()
		local on = not set[name]
		set[name] = on or nil
		save_zen_workspaces(set)
		apply_zen(on)
	end, name, 300)
end
-- Meh+0 or Meh+6 (so there's no workspace 6, below)
hl.bind(MEH .. " + 0", toggle_zen)
hl.bind(MEH .. " + 6", toggle_zen)

-- Show/hide Noctalia's dock. No key for it: run the launcher's Toggle Dock
-- entry (home.nix), i.e. `hyprctl eval 'toggle_dock()'`. Snapped windows grow
-- into its space or move clear of it right away. Does nothing in zen mode
-- (the dock's already hidden there).
local function toggle_dock()
	if zen_shown then
		return
	end
	refit_snapped(function()
		local hide = not dock_hidden()
		if hide then
			os.remove(DOCK_FILE)
		else
			local f = io.open(DOCK_FILE, "w")
			if f then
				f:close()
			end
		end
		dock_space = hide and 0 or DOCK_SPACE
		-- show/hide rather than toggle, so Noctalia can't drift out of step
		hl.exec_cmd("noctalia msg " .. (hide and "dock-hide" or "dock-show"))
	end)
end
_G.toggle_dock = toggle_dock

-- The bar's tile-size button: switches snaps between the whole screen and a
-- centered 75% x 90% (TILE_WIDTH/HEIGHT_NARROW, above), i.e. `hyprctl eval
-- 'toggle_tile_scale()'`. Snapped windows are re-fitted right away. The
-- button's look (icon, tooltip, lit up while narrow) goes in
-- zz-tile-scale-state.toml next to Noctalia's config.toml, like game mode's.
local TILE_SCALE_TOML = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
	.. "/noctalia/zz-tile-scale-state.toml"

local function write_tile_scale_state()
	local w, h = math.floor(TILE_WIDTH_NARROW * 100 + 0.5), math.floor(TILE_HEIGHT_NARROW * 100 + 0.5)
	local want = tile_narrow
			and string.format(
				'# Tiles are %d%% wide, %d%% tall (written by dotfiles/hypr/hyprland.lua)\n[widget.tile_scale]\nglyph = "viewport-narrow"\ncapsule = true\ncapsule_fill = "primary"\ncolor = "on_primary"\ntooltip = "Tile size: %d%% x %d%%"\n',
				w,
				h,
				w,
				h
			)
		or "# Tiles are full size (written by dotfiles/hypr/hyprland.lua)\n"
	-- Only rewrite (and reload Noctalia) when it changed: this also runs on
	-- every config reload.
	local f = io.open(TILE_SCALE_TOML, "r")
	local have = f and f:read("*a")
	if f then
		f:close()
	end
	if have == want then
		return
	end
	f = io.open(TILE_SCALE_TOML, "w")
	if f then
		f:write(want)
		f:close()
		hl.exec_cmd("noctalia msg config-reload")
	end
end

_G.toggle_tile_scale = function()
	refit_snapped(function()
		tile_narrow = not tile_narrow
		if tile_narrow then
			local f = io.open(TILE_SCALE_FILE, "w")
			if f then
				f:close()
			end
		else
			os.remove(TILE_SCALE_FILE)
		end
		write_tile_scale_state()
	end)
end

write_tile_scale_state()

hl.on("workspace.active", function()
	local name = active_workspace_name()
	if name then
		apply_zen(zen_workspaces()[name] == true)
		update_zen_dim() -- (another zen workspace: its own bottom window)
	end
end)

apply_zen(zen_workspaces()[active_workspace_name() or ""] == true, false)

hl.bind(MEH .. " + H", snap(RECTS.left_half))
hl.bind(MEH .. " + L", snap(RECTS.right_half))
hl.bind(MEH .. " + SHIFT + H", snap(RECTS.left_two_thirds))
hl.bind(MEH .. " + SHIFT + L", snap(RECTS.right_third))
hl.bind(MEH .. " + space", snap(RECTS.maximize))
hl.bind(MEH .. " + SHIFT + space", snap(RECTS.center))

-- Meh+arrows: focus the window in that direction (Meh+H/L snap, above)
hl.bind(MEH .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(MEH .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(MEH .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(MEH .. " + down", hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-5 always exist, so the bar always shows five dots.
for i = 1, 5 do
	hl.workspace_rule({ workspace = tostring(i), persistent = true })
end

-- Meh+1..9: workspaces; Meh+Shift+1..9: send window there. Not 6: Meh+6 is
-- zen mode (above).
for i = 1, 9 do
	if i ~= 6 then
		hl.bind(MEH .. " + " .. i, hl.dsp.focus({ workspace = i }))
		hl.bind(MEH .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
	end
end

-- Super+drag moves windows, Super+right-drag resizes
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Drop a Super+dragged window against a screen edge to snap it, like Windows
-- or Rectangle on the Mac: left / right edge = that half, top edge = maximize,
-- near a corner (on either edge) = that quarter. The bottom edge only does the
-- corners. Uses the monitor the cursor is on.
local EDGE = 6 -- px from the screen edge that counts as touching it
local CORNER = 0.15 -- how far along an edge (fraction) counts as the corner
local function drop_target(c, m)
	local scale = m.scale or 1
	local w, h = m.width / scale, m.height / scale
	local x, y = c.x - m.x, c.y - m.y
	local left, right = x <= EDGE, x >= w - 1 - EDGE
	local top, bottom = y <= EDGE, y >= h - 1 - EDGE
	local near_top, near_bottom = y < h * CORNER, y > h * (1 - CORNER)
	local near_left, near_right = x < w * CORNER, x > w * (1 - CORNER)
	if left or right then
		local side = left and "left" or "right"
		if near_top then
			return RECTS["top_" .. side]
		elseif near_bottom then
			return RECTS["bottom_" .. side]
		end
		return RECTS[side .. "_half"]
	elseif top or bottom then
		local side = top and "top" or "bottom"
		if near_left then
			return RECTS[side .. "_left"]
		elseif near_right then
			return RECTS[side .. "_right"]
		end
		return top and RECTS.maximize or nil
	end
end
hl.bind("SUPER + mouse:272", function()
	local win, c, m = hl.get_active_window(), hl.get_cursor_pos(), hl.get_monitor_at_cursor()
	local rect = win and c and m and drop_target(c, m)
	if rect then
		place("address:" .. win.address, rect, m)
	end
end, { release = true })

------------------
---- APP KEYS ----
------------------

-- Meh+key: open the app if it isn't running, focus it if it is, and hide it
-- (all its windows, like Cmd+H) if it's already focused (same keys as GNOME).
-- `classes` are the window classes the app may report (checked ignoring case;
-- `hyprctl clients` shows them). With several windows, the most recently used
-- one wins; a window hidden with Cmd+H is brought back first.
local function app(classes, cmd)
	local want = {}
	for _, c in ipairs(classes) do
		want[c:lower()] = true
	end
	local function matches(w)
		local class, initial = (w.class or ""):lower(), (w.initial_class or ""):lower()
		return w.mapped and (want[class] or want[initial])
	end
	return function()
		local active = hl.get_active_window()
		if active and matches(active) and not (active.workspace and active.workspace.special) then
			for _, w in ipairs(hl.get_windows() or {}) do
				if matches(w) and not (w.workspace and w.workspace.special) then
					hl.dispatch(hl.dsp.window.move({
						workspace = "special:hidden",
						follow = false,
						window = "address:" .. w.address,
					}))
				end
			end
			return
		end

		local best
		for _, w in ipairs(hl.get_windows() or {}) do
			if matches(w) and (not best or w.focus_history_id < best.focus_history_id) then
				best = w
			end
		end
		if not best then
			hl.exec_cmd(cmd)
			return
		end
		local sel = "address:" .. best.address
		if best.workspace and best.workspace.special then
			local ws = hl.get_active_workspace()
			hl.dispatch(hl.dsp.window.move({ workspace = ws and ws.id or 1, window = sel }))
		end
		hl.dispatch(hl.dsp.focus({ window = sel }))
		hl.dispatch(hl.dsp.window.bring_to_top())
	end
end

hl.bind(MEH .. " + G", app({ "GitHub Desktop", "github-desktop", "GitHubDesktop" }, "github-desktop"))
hl.bind(MEH .. " + C", app({ "zen-beta" }, "zen-beta"))
hl.bind(MEH .. " + X", app({ "dev.zed.Zed", "Zed", "zed" }, "zeditor"))
hl.bind(MEH .. " + T", app({ "com.mitchellh.ghostty" }, terminal))
hl.bind(MEH .. " + E", app({ "geary", "org.gnome.Geary" }, "geary"))
hl.bind(MEH .. " + N", app({ "obsidian", "md.obsidian.Obsidian" }, "obsidian"))
hl.bind(MEH .. " + A", app({ "com.anthropic.Claude", "Claude" }, "claude-desktop"))
hl.bind(MEH .. " + R", app({ "org.gnome.Nautilus", "nautilus" }, "nautilus"))
hl.bind(MEH .. " + D", app({ "discord" }, "discord"))

-- also `hyprctl eval 'switcher_focus("0x...")'`: the Cmd+Tab app switcher
-- (dotfiles/noctalia/plugins/app-switcher) picking an app's window, by address.
-- Brought back first if Cmd+H hid it, and raised (windows float).
_G.switcher_focus = function(address)
	local sel = "address:" .. address
	local bare = address:gsub("^0x", "")
	for _, w in ipairs(hl.get_windows() or {}) do
		if tostring(w.address):gsub("^0x", "") == bare and w.workspace and w.workspace.special then
			local ws = hl.get_active_workspace()
			hl.dispatch(hl.dsp.window.move({ workspace = ws and ws.id or 1, window = sel }))
		end
	end
	hl.dispatch(hl.dsp.focus({ window = sel }))
	hl.dispatch(hl.dsp.window.bring_to_top())
end

-- also `hyprctl eval 'open_clocks()'`: the launcher's Clocks entry (home.nix).
-- Clocks keeps running with its window closed or hidden, and opening it again
-- the usual way didn't bring the window forward.
_G.open_clocks = app({ "org.gnome.clocks" }, "gnome-clocks")

-- Meh+W: Noctalia's Wallhaven browser (plugin enabled in dotfiles/noctalia)
hl.bind(MEH .. " + W", hl.dsp.exec_cmd("noctalia msg panel-toggle noctalia/wallhaven:browser"))

-------------------------
---- LAPTOP FN KEYS  ----
-------------------------

-- Through Noctalia so its on-screen indicators show.
local fn = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("noctalia msg volume-up"), fn)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("noctalia msg volume-down"), fn)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("noctalia msg volume-mute"), fn)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("noctalia msg brightness-up"), fn)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("noctalia msg brightness-down"), fn)

-----------------------
---- BORDER COLORS ----
-----------------------

-- Thin gray window borders like the Mac's: light gray on dark mode's windows,
-- darker gray on light mode's, the focused window's a shade stronger. Picked
-- from GNOME's color-scheme (the light / dark mode apps and Noctalia follow);
-- follow-appearance.sh calls apply_border_colors() whenever it changes.
local BORDER_COLORS = {
	dark = { active = "rgb(5e5e5e)", inactive = "rgb(404040)" },
	light = { active = "rgb(a8a8a8)", inactive = "rgb(cccccc)" },
}

-- `hyprctl eval 'apply_border_colors()'`
_G.apply_border_colors = function()
	local p = io.popen("gsettings get org.gnome.desktop.interface color-scheme")
	local scheme = p and p:read("*a") or ""
	if p then
		p:close()
	end
	local c = BORDER_COLORS[scheme:find("dark", 1, true) and "dark" or "light"]
	hl.config({ general = { col = { active_border = c.active, inactive_border = c.inactive } } })
end
apply_border_colors()
