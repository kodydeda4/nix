-- Space t b: the background on / off. Off, the editor is see-through like the
-- file tree: the code, its gutter, the tab bar, the status bar, the `:` box
-- and the ⌘⇧Y terminal lose their solid background, so whatever's behind
-- Ghostty shows through. In Hyprland's zen mode 2 (Meh+7, dotfiles/hypr), that's
-- the dimmed wallpaper. Popups stay solid. Remembered across restarts (a flag
-- file, like Space t i's indent lines).
--
-- configs/glass.lua takes the background off the theme's groups after every
-- theme reload; options.lua's tab bar colors and configs/code_syntax.lua's
-- editor colors check M.off themselves.

local M = {}

local flag = vim.fn.stdpath "state" .. "/background-off"
M.off = vim.uv.fs_stat(flag) ~= nil

-- the editor's and the terminal's background colors, from the last theme load
local colors = {}

-- take the background off every group drawn in those colors, and off the tab
-- bar's
function M.strip()
  if not M.off then
    return
  end
  local editor = vim.api.nvim_get_hl(0, { name = "XcodeEditor", link = false }).bg
  if editor then
    colors = { [editor] = true } -- the theme just loaded: start over
  end
  local term = vim.api.nvim_get_hl(0, { name = "GhosttyTerm", link = false }).bg
  if term then
    colors[term] = true
  end
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    if hl.bg and not hl.link and (colors[hl.bg] or name:match "^Tb") then
      hl.bg = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

function M.toggle()
  M.off = not M.off
  if M.off then
    vim.fn.writefile({}, flag)
  else
    vim.fn.delete(flag)
  end
  -- reload the theme, like a light / dark switch (configs/appearance.lua), so
  -- everything built from it is redrawn with or without the background
  require("base46").load_all_highlights()
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
end

return M
