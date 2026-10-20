--!nonstrict
-- Cmd+Tab app switcher: one tile per app (its windows merged), most recently
-- used first, so the app you were in is first and the one before it starts
-- selected. Windows come from `hyprctl clients -j`; picking an app focuses its
-- most recent window through switcher_focus() in dotfiles/hypr/hyprland.lua.
--
-- Keys, with Cmd held (keyd sends them as Alt+key):
--   h / l, ← / →, Tab / Shift+Tab, Cmd+Tab again   previous / next
--   j / k, ↓ / ↑                                   down / up a row
--   let go of Cmd                                  switch (keyd lets go of Alt)
--   Enter or Space                                 switch
--   Esc                                            cancel
--
-- Two rows show at a time; the grid moves a row when the selection leaves
-- them. (Done by hand: ui.scroll's revealKey needs a newer Noctalia.)

local PANEL_ID = "kody/app-switcher:switcher"
local COLUMNS = 4
local VISIBLE_ROWS = 2
local GAP = 6
local ICON_SIZE = 112

local apps = {} -- { name, class, address, icon }
local selected = 1
local firstRow = 1 -- top row on screen
local isOpen = false
local loading = false

local render

-- ── app names from desktop entries ─────────────────────────────────────────

local APP_DIRS = {
  (noctalia.getenv("XDG_DATA_HOME") or "~/.local/share") .. "/applications",
  "~/.nix-profile/share/applications",
  "/etc/profiles/per-user/" .. (noctalia.getenv("USER") or "") .. "/share/applications",
  "/run/current-system/sw/share/applications",
}

local function desktopField(content, field)
  return content:match("\n" .. field .. "=([^\n]*)") or content:match("^" .. field .. "=([^\n]*)")
end

-- lowercased window class / desktop id -> app name, built once from every
-- desktop entry (by file name and by StartupWMClass)
local nameIndex = nil
local function buildNameIndex()
  nameIndex = {}
  for _, dir in ipairs(APP_DIRS) do
    local path = noctalia.expandPath(dir)
    local ok, entries = pcall(noctalia.listDir, path)
    if ok and type(entries) == "table" then
      for _, entry in ipairs(entries) do
        local file = if type(entry) == "table" then entry.name else entry
        if type(file) == "string" and file:match("%.desktop$") then
          local content = noctalia.readFile(path .. "/" .. file)
          if content then
            -- only the main [Desktop Entry] section, not its actions
            content = content:match("^(.-)\n%[Desktop Action") or content
            local name = desktopField(content, "Name")
            if name then
              local id = file:gsub("%.desktop$", ""):lower()
              nameIndex[id] = nameIndex[id] or name
              local wmClass = desktopField(content, "StartupWMClass")
              if wmClass then
                nameIndex[wmClass:lower()] = nameIndex[wmClass:lower()] or name
              end
            end
          end
        end
      end
    end
  end
end

local function appName(class)
  if not nameIndex then
    buildNameIndex()
  end
  local name = nameIndex[class:lower()]
  if name then
    return name
  end
  -- org.gnome.Clocks -> Clocks, zen-beta -> Zen-beta
  local last = class:match("([^.]+)$") or class
  return last:sub(1, 1):upper() .. last:sub(2)
end

-- ── window list ────────────────────────────────────────────────────────────

local function loadApps()
  loading = true
  noctalia.runAsync({ "hyprctl", "clients", "-j" }, function(result)
    loading = false
    noctalia.writeFile("/tmp/claude-1000/clients.log", "exit=" .. tostring(result.exitCode) .. " timedOut=" .. tostring(result.timedOut) .. " len=" .. #(result.stdout or "") .. " err=" .. tostring(result.stderr) .. "\n") -- DEBUG
    local ok, clients = pcall(noctalia.json.decode, result.stdout or "")
    if not ok or type(clients) ~= "table" then
      apps = {}
      if isOpen then
        render()
      end
      return
    end

    -- each app's most recently used window
    local byClass = {}
    for _, c in ipairs(clients) do
      local class = c.class ~= "" and c.class or c.initialClass
      if c.mapped and type(class) == "string" and class ~= "" then
        local key = class:lower()
        local best = byClass[key]
        if not best or c.focusHistoryID < best.focusHistoryID then
          byClass[key] = { class = class, address = c.address, focusHistoryID = c.focusHistoryID }
        end
      end
    end

    apps = {}
    for _, app in pairs(byClass) do
      table.insert(apps, app)
    end
    table.sort(apps, function(a, b)
      return a.focusHistoryID < b.focusHistoryID
    end)
    for _, app in ipairs(apps) do
      app.name = appName(app.class)
      app.icon = noctalia.appIconPath(app.class, ICON_SIZE * 2)
    end

    -- start on the app before the current one, like the Mac
    selected = if #apps >= 2 then 2 else 1
    firstRow = 1
    if isOpen then
      render()
    end
  end, 2000)
end

-- ── actions ────────────────────────────────────────────────────────────────

-- wrap: "list" goes around the whole list (past the last app to the first),
-- "row" around the selected row (past its last app to its first), "column"
-- around its column (past the bottom app to the top one), nil stops
-- at the ends
local function move(delta, wrap)
  if #apps == 0 then
    return
  end
  local target = selected + delta
  if wrap == "list" then
    target = ((target - 1) % #apps) + 1
  elseif wrap == "row" then
    local first = math.floor((selected - 1) / COLUMNS) * COLUMNS + 1
    local count = math.min(COLUMNS, #apps - first + 1)
    target = first + ((selected - first + delta) % count)
  elseif wrap == "column" then
    -- delta is ±COLUMNS: a row down / up, around the selected app's column
    local column = (selected - 1) % COLUMNS
    local rows = math.floor((#apps - 1 - column) / COLUMNS) + 1
    local row = math.floor((selected - 1) / COLUMNS)
    target = ((row + delta / COLUMNS) % rows) * COLUMNS + column + 1
  else
    target = math.clamp(target, 1, #apps)
  end
  if target ~= selected then
    selected = target
    -- keep the selected row on screen
    local row = math.ceil(selected / COLUMNS)
    if row < firstRow then
      firstRow = row
    elseif row > firstRow + VISIBLE_ROWS - 1 then
      firstRow = row - VISIBLE_ROWS + 1
    end
    render()
  end
end

local function pick(index)
  local app = apps[index]
  panel.close()
  if app then
    noctalia.runAsync({ "hyprctl", "eval", `switcher_focus("{app.address}")` })
  end
end

-- ── UI ─────────────────────────────────────────────────────────────────────

local function tile(app, index)
  local isSelected = index == selected
  local icon = if app.icon
    then ui.image({ path = app.icon, width = ICON_SIZE, height = ICON_SIZE, fit = "contain" })
    else ui.glyph({ name = "app-window", size = ICON_SIZE, color = "on_surface_variant" })
  return ui.column({
    key = `app_{app.class}`,
    flexGrow = 1,
    gap = 6,
    align = "center",
    justify = "center",
    radius = 12,
    -- solid, not see-through: on the grid's solid background (render)
    fill = if isSelected then "primary/0.22" else "surface_variant",
    border = if isSelected then "primary" else "outline/0.25",
    borderWidth = if isSelected then 2 else 1,
    onClick = function()
      pick(index)
    end,
  }, {
    icon,
    ui.label({
      text = app.name,
      fontSize = 14,
      fontWeight = if isSelected then "bold" else "medium",
      color = "on_surface",
      maxLines = 1,
      textAlign = "center",
    }),
  })
end

render = function()
  if #apps == 0 then
    panel.render(ui.column({ flexGrow = 1, align = "center", justify = "center" }, {
      ui.label({
        text = if loading then "" else "No open apps",
        fontSize = 15,
        color = "on_surface_variant",
      }),
    }))
    return
  end

  -- the rows on screen; a missing tile or row is a blank of the same size, so
  -- tiles keep their size at the end of the list
  local rows = {}
  for row = firstRow, firstRow + VISIBLE_ROWS - 1 do
    local cells = {}
    for column = 1, COLUMNS do
      local index = (row - 1) * COLUMNS + column
      if apps[index] then
        table.insert(cells, tile(apps[index], index))
      else
        table.insert(cells, ui.spacer({ key = `blank_{column}`, flexGrow = 1 }))
      end
    end
    table.insert(rows, ui.row({ key = `row_{row - firstRow}`, flexGrow = 1, gap = GAP, align = "stretch" }, cells))
  end

  -- a solid background: the panel itself is glass (shell.panel in the config),
  -- which let whatever was behind show through the grid
  panel.render(ui.column({ flexGrow = 1, gap = GAP, align = "stretch", fill = "surface", radius = 12 }, rows))
end

-- ── lifecycle ──────────────────────────────────────────────────────────────

function onOpen(_context)
  isOpen = true
  render()
  loadApps()
end

function onClose()
  isOpen = false
end

-- { step, wrap } (see move): h / l go around the selected row (l on its last
-- app goes to its first), j / k around its column (j on the bottom goes to the top)
local KEYS = {
  h = { -1, "row" }, left = { -1, "row" }, ["alt+h"] = { -1, "row" },
  l = { 1, "row" }, right = { 1, "row" }, ["alt+l"] = { 1, "row" },
  j = { COLUMNS, "column" }, down = { COLUMNS, "column" }, ["alt+j"] = { COLUMNS, "column" },
  k = { -COLUMNS, "column" }, up = { -COLUMNS, "column" }, ["alt+k"] = { -COLUMNS, "column" },
}

function onKey(chord, pressed)
  if not pressed then
    -- Cmd let go: keyd held Alt for it since Cmd+Tab
    if chord == "alt_l" then
      pick(selected)
    end
    return
  end
  if KEYS[chord] then
    move(KEYS[chord][1], KEYS[chord][2])
  elseif chord == "tab" then
    move(1, "list")
  elseif chord == "shift+tab" or chord == "alt+shift+tab" then
    move(-1, "list")
  elseif chord == "return" or chord == "kp_enter" or chord == "space" then
    pick(selected)
  end
end

-- `noctalia msg plugin kody/app-switcher:switcher all next` (Cmd+Tab):
-- opens the switcher, or moves to the next app while it's open
function onIpc(event, _payload)
  if event == "next" then
    if isOpen then
      move(1, "list")
    else
      noctalia.togglePanel(PANEL_ID)
    end
  elseif event == "previous" and isOpen then
    move(-1, "list")
  end
end
