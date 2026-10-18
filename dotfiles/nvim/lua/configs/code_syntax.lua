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
-- popups about the code (completion menu, its docs, signature help, LSP
-- hover) take the other theme's colors too when opened from a non-Swift file:
-- these groups of it on top of its syntax ones
local POPUP = { "blink" }
local DEFAULT_POPUP = { "NormalFloat", "FloatBorder", "Pmenu", "PmenuSel", "PmenuSbar", "PmenuThumb" }
-- blink's popups, by their buffer's filetype (LSP hover is found by the
-- w:lsp_floating_bufnr Neovim gives it)
local CODE_POPUPS = { ["blink-cmp-menu"] = true, ["blink-cmp-documentation"] = true, ["blink-cmp-signature"] = true }

local function fresh(name)
  package.loaded["base46.integrations." .. name] = nil
  return require("base46").get_integration(name)
end

-- the syntax highlight groups of base46 theme `name`, without loading it,
-- and the groups its code popups use
local function syntax_of(name)
  local opts = require("nvconfig").base46
  local saved = opts.theme
  opts.theme = name -- base46 reads the theme from here
  local ok, result, popup = pcall(function()
    local hl, popup = {}, {}
    for _, int in ipairs(SYNTAX) do
      hl = vim.tbl_extend("force", hl, fresh(int))
    end
    for _, int in ipairs(POPUP) do
      popup = vim.tbl_extend("force", popup, fresh(int))
    end
    local defaults = fresh "defaults"
    for _, group in ipairs(DEFAULT_SYNTAX) do
      hl[group] = defaults[group]
    end
    for _, group in ipairs(DEFAULT_POPUP) do
      popup[group] = defaults[group]
    end

    -- the same calmer look configs/xcode_theme.lua gives the Xcode theme's
    -- menu: the selected row in the selection color with normal text, the
    -- letters you typed brighter and bold (instead of black on bright blue,
    -- and blue letters), grey outlines
    local text, bg = defaults.Normal.fg, defaults.Normal.bg
    local mix = require("base46.colors").mix
    popup.PmenuSel = { fg = text, bg = defaults.Visual.bg }
    popup.BlinkCmpLabel = { fg = mix(bg, text, 75) }
    popup.BlinkCmpLabelMatch = { fg = text, bold = true }
    popup.BlinkCmpSignatureHelpActiveParameter = { fg = text, bold = true }
    popup.FloatBorder = popup.BlinkCmpDocBorder

    hl.__text = text
    return hl, popup
  end)
  opts.theme = saved
  -- leave base46's modules as the current theme built them
  for _, int in ipairs(vim.list_extend(vim.list_extend({}, SYNTAX), POPUP)) do
    package.loaded["base46.integrations." .. int] = nil
  end
  package.loaded["base46.integrations.defaults"] = nil
  if not ok then
    vim.notify("code_syntax: " .. tostring(result), vim.log.levels.WARN)
    return nil
  end
  return result, popup
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
-- the other theme's syntax + popup groups, and the popup namespaces built
-- from them (one per 'winhighlight', which they replace)
local popup_hl
local popup_ns = {}

local function new_ns(label, hl)
  -- a new namespace each build, so groups from an older one don't linger
  local ns = vim.api.nvim_create_namespace("code_syntax_" .. label .. "_" .. vim.uv.hrtime())
  ours[ns] = true
  for group, spec in pairs(hl) do
    pcall(vim.api.nvim_set_hl, ns, group, spec)
  end
  return ns
end

-- `preview`: use this theme instead of chadrc's (Space t c, while picking)
function M.build(preview)
  popup_hl, popup_ns = nil, {}
  local polish = (current_theme() or {}).polish_hl or {}
  local editor = (polish.defaults or {}).XcodeEditor
  if not editor then
    M.ns, M.xcode_ns = 0, 0 -- not an Xcode theme: leave windows alone
    return
  end
  M.xcode_ns = new_ns("xcode", { Normal = editor, NormalNC = editor })

  package.loaded.chadrc = nil
  local themes = require("chadrc").base46
  local name = preview or themes["code_theme_" .. vim.o.background]
  local hl, popup
  if name then
    hl, popup = syntax_of(name)
  end
  if not hl then
    M.ns = M.xcode_ns -- no other theme: Xcode colors everywhere
    return
  end
  fill_gaps(hl)
  popup_hl = vim.tbl_extend("force", hl, popup)
  hl.Normal = editor
  hl.NormalNC = editor
  M.ns = new_ns(name, hl)
end

-- a group of popup_hl as a plain spec, following links (in popup_hl first,
-- then the global groups)
local function resolve(group, depth)
  local spec = popup_hl[group]
  if not spec then
    return vim.api.nvim_get_hl(0, { name = group, link = false })
  end
  if spec.link and (depth or 0) < 10 then
    local own = vim.deepcopy(spec)
    own.link = nil
    return vim.tbl_extend("force", resolve(spec.link, (depth or 0) + 1), own)
  end
  return spec
end

-- the namespace for a code popup with this 'winhighlight': the other theme's
-- groups, plus the popup's own remaps (Normal:BlinkCmpMenu...) done in them,
-- since a window namespace replaces 'winhighlight'
local function popup_ns_for(whl)
  if not popup_ns[whl] then
    local hl = vim.deepcopy(popup_hl)
    hl.Normal = resolve "NormalFloat"
    for from, to in whl:gmatch "([^,:]+):([^,]+)" do
      hl[from] = to == "None" and {} or resolve(to)
    end
    for group, spec in pairs(hl) do
      if spec.link then
        hl[group] = resolve(group)
      end
    end
    popup_ns[whl] = new_ns("popup", hl)
  end
  return popup_ns[whl]
end

-- the file a code popup is about: the current one for blink's (they never
-- take the cursor), the one LSP hover was asked from; nil for other windows
local function popup_source(win)
  if CODE_POPUPS[vim.bo[vim.api.nvim_win_get_buf(win)].filetype] then
    return vim.api.nvim_get_current_buf()
  end
  local buf = vim.w[win].lsp_floating_bufnr
  return buf and vim.api.nvim_buf_is_valid(buf) and buf or nil
end

-- regular file windows: Swift gets M.xcode_ns, anything else M.ns. Code
-- popups opened from a non-Swift file get a popup namespace. The file tree,
-- pickers, other floats... are left as they are (nvim-tree and 'winhighlight'
-- set up their own namespaces).
local function update(win)
  if not vim.api.nvim_win_is_valid(win) or M.xcode_ns == 0 then
    return
  end
  local current = vim.api.nvim_get_hl_ns { winid = win }
  local buf = vim.api.nvim_win_get_buf(win)
  local file = vim.bo[buf].buftype == "" and vim.api.nvim_win_get_config(win).relative == ""
  local source = not file and popup_hl and popup_source(win)
  if file then
    local want = vim.bo[buf].filetype == "swift" and M.xcode_ns or M.ns
    if want ~= current then
      vim.api.nvim_win_set_hl_ns(win, want)
    end
  elseif source and vim.bo[source].filetype ~= "swift" then
    local want = popup_ns_for(vim.wo[win].winhighlight)
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
