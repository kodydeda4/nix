require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

vim.o.cmdheight = 0 -- hide the empty command-line row under the status bar

-- code folding follows the syntax tree (types, functions, closures...), and
-- files open with everything unfolded; ⌘> / ⌘< fold (mappings.lua)
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- a folded line keeps its colors, plus a "⋯ N lines" marker (configs/fold_marker.lua)
vim.o.foldtext = "v:lua.XcodeFoldText()"
require "configs.fold_marker"
vim.o.foldlevelstart = 99
vim.opt.fillchars:append { fold = " " }

-- Indent with real tabs, shown 2 columns wide (NvChad defaults to spaces).
local function use_tabs()
  vim.bo.expandtab = false
  vim.bo.tabstop = 2
  vim.bo.shiftwidth = 2
  vim.bo.softtabstop = 0
end
vim.o.expandtab = false
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 0
-- re-apply per file type (some built-in filetype settings switch to 4 / spaces),
-- unless the project's .editorconfig says otherwise
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    local ec = vim.b.editorconfig or {}
    if ec.indent_style or ec.indent_size or ec.tab_width then return end
    use_tabs()
  end,
})

-- OLED status bar + buffer tabs: every St_* (status bar, all modes) and Tb*
-- (tab bar) group gets a black background, and colored blocks become colored
-- text instead. Re-applied when the theme reloads and when buffers open, since
-- NvChad loads the tab bar's colors lazily.
-- the tab bar is a subtle grey strip; only the active tab is black, so it
-- stands out (and inactive tabs stay easy to see)
local TAB_BAR_BG = "#1a1a1f"

local function oled_bars()
  local light = vim.o.background == "light"
  -- light themes: the same flat style on the theme's light grey bar, with the
  -- tab strip a step darker and the active tab on the editor's white
  local colors = light and require("base46").get_theme_tb "base_30"
  for name in pairs(vim.api.nvim_get_hl(0, {})) do
    if name:match "^St_" or name:match "^Tb" or name == "StatusLine" or name == "StatusLineNC" or name == "StText" then
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      local new = vim.tbl_extend("force", {}, hl)
      if hl.bg then
        local r, g, b = bit.rshift(hl.bg, 16), bit.band(bit.rshift(hl.bg, 8), 0xff), bit.band(hl.bg, 0xff)
        -- dark: any bright block; light: any colored (not grey) block
        local block = light and (math.max(r, g, b) - math.min(r, g, b) > 40)
          or (not light and (0.299 * r + 0.587 * g + 0.114 * b) > 60)
        if block then
          new.fg = hl.bg -- colored block -> colored text
        end
      end
      local grey = name:match "^Tb" and not name:match "^TbBufOn"
      if light then
        new.bg = grey and colors.black2 or (name:match "^Tb" and colors.black or colors.statusline_bg)
      else
        new.bg = grey and TAB_BAR_BG or "#000000"
      end
      -- the status bar: no background of its own. Under the file tree that's
      -- the glass; under the editor configs/sidebar_status.lua draws it solid.
      if not name:match "^Tb" then
        new.bg = nil
        new.reverse = nil
      end
      -- the empty rest of the tab bar, above the editor: the editor's color
      local editor = vim.api.nvim_get_hl(0, { name = "XcodeEditor", link = false })
      if name == "TbFill" then
        new.bg = editor.bg
      end
      -- inactive tabs: no block of their own, just dim text on the editor's
      -- background, so the current tab stands out
      if name:match "^TbBufOff" then
        new.bg = editor.bg
        if not name:match "Modified$" then
          -- the line numbers' grey; lighter still in light mode
          new.fg = light and "#bdbdc2" or vim.api.nvim_get_hl(0, { name = "LineNr", link = false }).fg
        end
      end
      -- the current tab: see-through too when the editor is (Space t b,
      -- mappings.lua); its brighter text still sets it apart
      if name:match "^TbBufOn" and not editor.bg then
        new.bg = nil
      end
      vim.api.nvim_set_hl(0, name, new)
    end
  end
end

oled_bars()
-- also after every theme reload: the theme picker (and its previews), Space t t
-- and saving a config file reload the bar colors without a
-- ColorScheme event, which left NvChad's colored blocks behind
-- base46 re-reads its own Lua modules on every theme reload, which would drop
-- changes made to them once; so they're applied whenever a module loads:
local function patch_module(name, patch)
  package.preload[name] = function()
    -- base46 is a lazy.nvim plugin: its folder comes from lazy, not the runtimepath
    local dir = require("lazy.core.config").plugins.base46.dir
    local rel = name:gsub("%.", "/")
    local path = vim.uv.fs_stat(dir .. "/lua/" .. rel .. ".lua") and (dir .. "/lua/" .. rel .. ".lua")
      or (dir .. "/lua/" .. rel .. "/init.lua")
    local mod = dofile(path)
    patch(mod)
    return mod
  end
  if package.loaded[name] then
    patch(package.loaded[name])
  end
end
patch_module("base46", function(base46)
  local load_all_highlights = base46.load_all_highlights
  base46.load_all_highlights = function(...)
    load_all_highlights(...)
    vim.schedule(oled_bars)
  end
end)
vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter", "ColorScheme", "BufAdd", "BufWinEnter", "TabNew" }, {
  callback = function() vim.schedule(oled_bars) end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  callback = function() vim.defer_fn(oled_bars, 50) end,
})

