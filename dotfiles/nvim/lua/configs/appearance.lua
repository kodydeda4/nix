-- Follow macOS light / dark mode: use chadrc's theme_light or theme_dark, and
-- switch as soon as the system appearance changes.

local M = {}

local chadrc_path = vim.fn.stdpath "config" .. "/lua/chadrc.lua"

-- rewrite `<key> = "..."` in chadrc so the choice sticks across restarts
local function save(key, theme)
  local file = io.open(chadrc_path, "r")
  if not file then
    return
  end
  local content = file:read "*a"
  file:close()
  local new = content:gsub("(%f[%w_]" .. key .. "%s*=%s*)\"[^\"]*\"", "%1\"" .. theme .. "\"", 1)
  if new ~= content then
    file = io.open(chadrc_path, "w")
    file:write(new)
    file:close()
  end
end

local function chadrc()
  package.loaded.chadrc = nil
  return require("chadrc").base46
end

local function apply(theme)
  if require("nvconfig").base46.theme == theme then
    return
  end
  require("nvchad.themes.utils").reload_theme(theme)
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false }) -- re-runs options.lua's bar colors
end

M.mode = nil -- "light" or "dark"

local function set_mode(mode)
  if mode == M.mode then
    return
  end
  M.mode = mode
  local theme = chadrc()["theme_" .. mode]
  if theme then
    save("theme", theme)
    apply(theme)
  end
end

-- AppleInterfaceStyle is "Dark" in dark mode and missing in light mode
local function check()
  vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(out)
    local mode = out.stdout:match "Dark" and "dark" or "light"
    vim.schedule(function()
      set_mode(mode)
    end)
  end)
end

-- Space t h: the picked theme becomes the one for the current mode
function M.save_pick(theme)
  save("theme", theme)
  save("theme_" .. (M.mode or vim.o.background), theme)
end

check()
local timer = vim.uv.new_timer()
timer:start(2000, 2000, check)
vim.api.nvim_create_autocmd("FocusGained", { callback = check })

return M
