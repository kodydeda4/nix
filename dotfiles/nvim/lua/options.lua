require "nvchad.options"

-- add yours here!

-- local o = vim.o
-- o.cursorlineopt ='both' -- to enable cursorline!

vim.o.cmdheight = 0 -- hide the empty command-line row under the status bar

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
  for name in pairs(vim.api.nvim_get_hl(0, {})) do
    if name:match "^St_" or name:match "^Tb" or name == "StatusLine" or name == "StText" then
      local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
      local new = vim.tbl_extend("force", {}, hl)
      if hl.bg then
        local r, g, b = bit.rshift(hl.bg, 16), bit.band(bit.rshift(hl.bg, 8), 0xff), bit.band(hl.bg, 0xff)
        if (0.299 * r + 0.587 * g + 0.114 * b) > 60 then
          new.fg = hl.bg -- colored block -> colored text
        end
      end
      local grey = name:match "^Tb" and not name:match "^TbBufOn"
      new.bg = grey and TAB_BAR_BG or "#000000"
      vim.api.nvim_set_hl(0, name, new)
    end
  end
end

oled_bars()
vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter", "ColorScheme", "BufAdd", "BufWinEnter", "TabNew" }, {
  callback = function() vim.schedule(oled_bars) end,
})
vim.api.nvim_create_autocmd("User", {
  pattern = "FilePost",
  callback = function() vim.defer_fn(oled_bars, 50) end,
})

