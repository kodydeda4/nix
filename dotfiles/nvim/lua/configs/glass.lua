-- Xcode-style translucent sidebar: the theme leaves Normal without a background
-- so Ghostty's glass shows through (the file tree), and every other window
-- draws a solid background instead: XcodeEditor for editor windows, the popup
-- background (NormalFloat) for floating windows. Only the sidebar is glass.

-- a popup whose background would come from Normal (none, so it'd be see-through)
-- gets NormalFloat's solid one
local function solid_float(win)
  local entries, normal = {}, "Normal"
  for entry in vim.wo[win].winhighlight:gmatch "[^,]+" do
    local from, to = entry:match "^([^:]+):(.+)$"
    if from == "Normal" then
      normal = to
    else
      entries[#entries + 1] = entry
    end
  end
  if vim.api.nvim_get_hl(0, { name = normal, link = false }).bg then
    return -- has its own background
  end
  table.insert(entries, 1, "Normal:NormalFloat")
  vim.wo[win].winhighlight = table.concat(entries, ",")
end

local function solid(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    solid_float(win)
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local whl = vim.wo[win].winhighlight
  if vim.bo[buf].filetype == "NvimTree" then
    -- no divider line: the glass sidebar meeting the solid editor is the edge
    vim.wo[win].fillchars = "vert: ,eob: "
    -- a 1-column left margin, so the tree starts in the same column as tmux's
    -- bar below (" 0 ○ ●"): an empty fold column, drawn in the tree's glass
    -- instead of the fold column's solid color
    vim.wo[win].foldcolumn = "1"
    vim.wo[win].statuscolumn = ""
    if not whl:find "FoldColumn:NvimTreeNormal" then
      local extra = "FoldColumn:NvimTreeNormal"
      vim.wo[win].winhighlight = whl == "" and extra or (whl .. "," .. extra)
    end
    return
  end
  -- terminals (⌘⇧Y) take Ghostty's own text and background (configs/ghostty_term.lua)
  local normal = vim.bo[buf].buftype == "terminal" and "GhosttyTerm" or "XcodeEditor"
  if whl:find("Normal:" .. normal .. ",") or whl:match("Normal:" .. normal .. "$") then
    return
  end
  local entries = { "Normal:" .. normal, "NormalNC:" .. normal }
  for entry in whl:gmatch "[^,]+" do
    if not entry:match "^NormalN?C?:" then
      entries[#entries + 1] = entry
    end
  end
  vim.wo[win].winhighlight = table.concat(entries, ",")
end

local function solid_all()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    solid(win)
  end
end
-- (many plugins open popups without window events, so also on entering windows
-- and the command line)
vim.api.nvim_create_autocmd({ "VimEnter", "WinNew", "WinEnter", "BufWinEnter", "FileType", "CmdlineEnter" }, {
  group = vim.api.nvim_create_augroup("XcodeGlass", { clear = true }),
  callback = function()
    vim.schedule(solid_all)
    vim.defer_fn(solid_all, 30) -- popups that appear right after the event
  end,
})

-- The tab bar's base, TabLineFill (Neovim links it to a grey), shows wherever
-- nothing else colors the tab bar: the block above the file tree, which stays
-- glass like the tree. Set here rather than only in the theme so it holds even
-- while base46 is still on an older compiled cache.
local function clear_tabline_fill()
  vim.api.nvim_set_hl(0, "TabLineFill", {})
  -- the column between the tree and the editor: solid, like the editor (also
  -- set in configs/xcode_theme.lua; here so it holds on an older cache)
  vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { link = "XcodeEditor" })
  -- noice's popups (messages, prompts) take Normal by default, which has no
  -- background: give them the solid popup one
  for _, group in ipairs { "NoicePopup", "NoiceMini", "NoiceConfirm", "NoiceSplit" } do
    vim.api.nvim_set_hl(0, group, { link = "NormalFloat" })
  end
  -- the `:` box: the editor's own background with a quiet grey rounded outline
  -- and a grey prompt icon (noice's defaults are a teal outline in a grey block)
  local editor = vim.api.nvim_get_hl(0, { name = "XcodeEditor", link = false })
  local grey = vim.api.nvim_get_hl(0, { name = "LineNr", link = false }).fg
  vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { fg = editor.fg, bg = editor.bg })
  for _, kind in ipairs { "", "Cmdline", "Search", "Filter", "Lua", "Help", "Input", "Calculator", "IncRename" } do
    vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder" .. kind, { fg = grey, bg = editor.bg })
    vim.api.nvim_set_hl(0, "NoiceCmdlineIcon" .. kind, { fg = grey })
  end
  -- the git branch in the status bar under the tree (configs/sidebar_status.lua):
  -- NvChad's grey, but a darker grey in light mode, where that one is too faint
  if vim.o.background == "light" then
    vim.api.nvim_set_hl(0, "SidebarBranch", { fg = "#6e6e73", bold = true })
  else
    vim.api.nvim_set_hl(0, "SidebarBranch", { link = "St_gitIcons" })
  end
end
clear_tabline_fill()
vim.api.nvim_create_autocmd("ColorScheme", { callback = clear_tabline_fill })
vim.api.nvim_create_autocmd("User", {
  pattern = "NvThemeReload",
  callback = function()
    vim.schedule(clear_tabline_fill)
  end,
})
