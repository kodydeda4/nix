-- Syntax colors for everything but Swift. The theme (sidebar, icons, bars,
-- backgrounds...) is always the Xcode one, and Swift windows use its syntax
-- colors too. Windows showing any other file get the syntax colors of chadrc's
-- code_theme_dark / code_theme_light through a window highlight namespace;
-- anything not in it (all the UI) falls back to the Xcode theme.

local M = {}

local function current_theme()
  local ok, theme = pcall(require, "themes." .. require("nvconfig").base46.theme)
  return ok and type(theme) == "table" and theme or nil
end

-- base46 integrations that are syntax highlighting, not UI
local SYNTAX = { "syntax", "treesitter", "semantic_tokens" }
-- syntax groups that live in base46's "defaults" next to the UI ones
local DEFAULT_SYNTAX = { "Comment", "Debug", "Exception", "Macro" }

local function fresh(name)
  package.loaded["base46.integrations." .. name] = nil
  return require("base46").get_integration(name)
end

-- the syntax highlight groups of base46 theme `name`, without loading it
local function syntax_of(name)
  local opts = require("nvconfig").base46
  local saved = opts.theme
  opts.theme = name -- base46 reads the theme from here
  local ok, result = pcall(function()
    local hl = {}
    for _, int in ipairs(SYNTAX) do
      hl = vim.tbl_extend("force", hl, fresh(int))
    end
    local defaults = fresh "defaults"
    for _, group in ipairs(DEFAULT_SYNTAX) do
      hl[group] = defaults[group]
    end
    hl.__text = defaults.Normal and defaults.Normal.fg
    return hl
  end)
  opts.theme = saved
  -- leave base46's modules as the current theme built them
  for _, int in ipairs(SYNTAX) do
    package.loaded["base46.integrations." .. int] = nil
  end
  package.loaded["base46.integrations.defaults"] = nil
  if not ok then
    vim.notify("code_syntax: " .. tostring(result), vim.log.levels.WARN)
    return nil
  end
  return result
end

-- the Xcode theme colors groups the other theme doesn't know (Swift-specific
-- captures, @lsp.typemod.*...); give those the closest group the other theme has
-- so they don't fall back to the Xcode colors
local function fill_gaps(hl)
  local current = require("nvconfig").base46.theme
  local ok, theme = pcall(require, "themes." .. current)
  local polish = ok and type(theme) == "table" and theme.polish_hl or {}
  for _, section in ipairs { "syntax", "treesitter" } do
    for group in pairs(polish[section] or {}) do
      if not hl[group] then
        local match
        local typ = group:match "^@lsp%.typemod%.([^.]+)%."
        if typ then
          match = hl["@lsp.type." .. typ]
        end
        local parent = group
        while not match and parent:find "%." do
          parent = parent:gsub("%.[^.]*$", "")
          match = hl[parent]
        end
        if not match and group:match "^@lsp" then
          match = hl["@type"] -- @lsp.type.type, @lsp.type.typeParameter
        end
        hl[group] = match and vim.deepcopy(match) or { fg = hl.__text }
      end
    end
  end
  hl.__text = nil
end

-- every file window gets one of two namespaces made here:
--   M.xcode_ns (Swift): just the solid editor background, everything else is
--     the Xcode theme itself
--   M.ns (other files): that background plus the other theme's syntax colors
-- A window namespace replaces 'winhighlight' (Neovim builds 'winhighlight' as a
-- window namespace too), so the solid XcodeEditor background configs/glass.lua
-- sets that way has to be in both.
M.ns = 0
M.xcode_ns = 0
local ours = {}

local function new_ns(label, hl)
  -- a new namespace each build, so groups from an older one don't linger
  local ns = vim.api.nvim_create_namespace("code_syntax_" .. label .. "_" .. vim.uv.hrtime())
  ours[ns] = true
  for group, spec in pairs(hl) do
    pcall(vim.api.nvim_set_hl, ns, group, spec)
  end
  return ns
end

function M.build()
  local polish = (current_theme() or {}).polish_hl or {}
  local editor = (polish.defaults or {}).XcodeEditor
  if not editor then
    M.ns, M.xcode_ns = 0, 0 -- not an Xcode theme: leave windows alone
    return
  end
  M.xcode_ns = new_ns("xcode", { Normal = editor, NormalNC = editor })

  package.loaded.chadrc = nil
  local themes = require("chadrc").base46
  local name = themes["code_theme_" .. vim.o.background]
  local hl = name and syntax_of(name)
  if not hl then
    M.ns = M.xcode_ns -- no other theme: Xcode colors everywhere
    return
  end
  fill_gaps(hl)
  hl.Normal = editor
  hl.NormalNC = editor
  M.ns = new_ns(name, hl)
end

-- regular file windows: Swift gets M.xcode_ns, anything else M.ns. The file
-- tree, pickers, floats... are left as they are (nvim-tree and 'winhighlight'
-- set up their own namespaces).
local function update(win)
  if not vim.api.nvim_win_is_valid(win) or M.xcode_ns == 0 then
    return
  end
  local current = vim.api.nvim_get_hl_ns { winid = win }
  local buf = vim.api.nvim_win_get_buf(win)
  local file = vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == ""
  if file then
    local want = vim.bo[buf].filetype == "swift" and M.xcode_ns or M.ns
    if want ~= current then
      vim.api.nvim_win_set_hl_ns(win, want)
    end
  elseif ours[current] then
    -- the window switched from a file to something else: hand it back to its
    -- 'winhighlight' (setting the option rebuilds its namespace)
    vim.api.nvim_win_set_hl_ns(win, 0)
    local whl = vim.wo[win].winhighlight
    vim.wo[win].winhighlight = ""
    vim.wo[win].winhighlight = whl
  end
end

function M.update_all()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    update(win)
  end
end

local group = vim.api.nvim_create_augroup("CodeSyntax", { clear = true })

vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "BufWinEnter", "BufEnter", "FileType" }, {
  group = group,
  callback = function()
    vim.schedule(M.update_all)
  end,
})

-- the theme reloaded (light / dark switch, theme picker...): rebuild for it
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "NvThemeReload",
  callback = function()
    vim.schedule(function()
      M.build()
      M.update_all()
    end)
  end,
})

-- base46 starts from its compiled cache and only recompiles when the theme
-- changes, so edits to chadrc or the theme files wouldn't show until then:
-- recompile when any of them is newer than the cache (or the Xcode theme's own
-- groups are missing, e.g. a cache left by another theme)
local function stale()
  local cache = vim.uv.fs_stat(vim.g.base46_cache .. "defaults")
  if not cache then
    return true
  end
  local config = vim.fn.stdpath "config" .. "/lua/"
  local sources = { config .. "chadrc.lua", config .. "configs/xcode_theme.lua" }
  vim.list_extend(sources, vim.fn.glob(config .. "themes/*.lua", false, true))
  for _, path in ipairs(sources) do
    local stat = vim.uv.fs_stat(path)
    if stat and stat.mtime.sec > cache.mtime.sec then
      return true
    end
  end
  local theme = current_theme()
  return theme and ((theme.polish_hl or {}).defaults or {}).XcodeEditor and vim.fn.hlexists "XcodeEditor" == 0
end
if stale() then
  require("base46").load_all_highlights()
end

M.build()

return M
