-- Terminals inside nvim (⌘⇧Y) use Ghostty's colors instead of the nvim theme's:
-- its 16-color palette, text and background, read from Ghostty's config and
-- theme files (the dark or light theme, following vim.o.background like Ghostty
-- follows macOS). configs/glass.lua gives terminal windows the GhosttyTerm group.
-- The palette is fixed when a terminal starts; text and background follow
-- light / dark switches right away.

local M = {}

local home = vim.env.HOME
local config_dir = (vim.env.XDG_CONFIG_HOME or (home .. "/.config")) .. "/ghostty"

local function read_lines(path)
  local f = path and io.open(path, "r")
  if not f then
    return nil
  end
  local lines = {}
  for line in f:lines() do
    lines[#lines + 1] = line
  end
  f:close()
  return lines
end

local function hex(value)
  value = vim.trim(value or "")
  local digits = value:match "^#?(%x%x%x%x%x%x)$"
  return digits and ("#" .. digits:lower()) or nil
end

-- "key = value" lines into colors (palette / foreground / background) and the
-- other keys we care about (theme, config-file)
local function parse(lines, into, dir)
  for _, line in ipairs(lines or {}) do
    local key, value = line:match "^%s*([%w-]+)%s*=%s*(.-)%s*$"
    if key == "palette" then
      local n, color = value:match "^(%d+)%s*=%s*(.+)$"
      if n and tonumber(n) < 16 and hex(color) then
        into.palette[tonumber(n)] = hex(color)
      end
    elseif key == "foreground" or key == "background" then
      into[key] = hex(value) or into[key]
    elseif key == "theme" then
      into.theme = value
    elseif key == "config-file" and dir then
      local path = value:gsub("^%?", "")
      if not path:match "^/" then
        path = dir .. "/" .. path
      end
      parse(read_lines(path), into)
    end
  end
  return into
end

local function theme_file(name)
  if name:match "^/" then
    return name
  end
  local dirs = {
    config_dir .. "/themes",
    vim.env.GHOSTTY_RESOURCES_DIR and (vim.env.GHOSTTY_RESOURCES_DIR .. "/themes"),
    "/Applications/Ghostty.app/Contents/Resources/ghostty/themes",
    "/usr/share/ghostty/themes",
  }
  for _, dir in pairs(dirs) do
    if vim.uv.fs_stat(dir .. "/" .. name) then
      return dir .. "/" .. name
    end
  end
end

-- the colors for the current light / dark mode; nil if Ghostty's config can't be read
local cache = {}
function M.colors()
  local mode = vim.o.background
  if cache[mode] ~= nil then
    return cache[mode] or nil
  end
  local lines = read_lines(config_dir .. "/config.ghostty") or read_lines(config_dir .. "/config")
  if not lines then
    cache[mode] = false
    return nil
  end
  local config = parse(lines, { palette = {} }, config_dir)
  -- "dark:A, light:B" or a single theme name
  local theme = config.theme
  if theme and theme:find ":" then
    theme = theme:match(mode .. ":%s*([^,]+)")
  end
  local colors = { palette = {} }
  if theme then
    parse(read_lines(theme_file(vim.trim(theme))), colors)
  end
  -- colors set in the config itself win over the theme's
  colors.palette = vim.tbl_extend("force", colors.palette, config.palette)
  colors.foreground = config.foreground or colors.foreground
  colors.background = config.background or colors.background
  cache[mode] = colors
  return colors
end

local function set_group()
  local colors = M.colors()
  if colors and (colors.foreground or colors.background) then
    vim.api.nvim_set_hl(0, "GhosttyTerm", { fg = colors.foreground, bg = colors.background })
  else
    vim.api.nvim_set_hl(0, "GhosttyTerm", { link = "XcodeEditor" })
  end
end
set_group()

local group = vim.api.nvim_create_augroup("GhosttyTerm", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_group })
vim.api.nvim_create_autocmd("OptionSet", { group = group, pattern = "background", callback = set_group })
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "NvThemeReload",
  callback = function()
    vim.schedule(set_group)
  end,
})

-- the palette: read once, when the terminal starts (b:terminal_color_N beats
-- NvChad's g:terminal_color_N)
vim.api.nvim_create_autocmd("TermOpen", {
  group = group,
  callback = function(args)
    local colors = M.colors()
    for n, color in pairs(colors and colors.palette or {}) do
      vim.b[args.buf]["terminal_color_" .. n] = color
    end
  end,
})

return M
