require "nvchad.autocmds"

-- light / dark theme follows macOS appearance
require "configs.appearance"

-- Swift keeps the Xcode syntax colors; other files get code_theme_dark / _light's
require "configs.code_syntax"

-- Starting without a file (`nvim` or `nvim some/folder`): the file tree opens
-- on the side and the cursor starts in an empty editor (not in the tree, so the
-- leader key works), like opening a project in Xcode.
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local args = vim.fn.argv()
    if #args > 1 or (#args == 1 and vim.fn.isdirectory(args[1]) == 0) then
      return -- a file was given: open just that
    end
    if #args == 1 then
      vim.cmd.cd(vim.fn.fnameescape(args[1]))
      -- the folder's own buffer: swap it for an empty one before nvim-tree takes
      -- over the window with it
      local dir_buf = vim.api.nvim_get_current_buf()
      vim.cmd.enew()
      pcall(vim.api.nvim_buf_delete, dir_buf, { force = true })
      -- and out of NvChad's tab bar list, or its next BufAdd errors on the
      -- missing buffer and aborts opening the file
      vim.t.bufs = vim.tbl_filter(vim.api.nvim_buf_is_valid, vim.t.bufs or {})
    end
    local editor = vim.api.nvim_get_current_win()
    vim.schedule(function()
      require("nvim-tree.api").tree.open()
      if vim.api.nvim_win_is_valid(editor) then
        vim.api.nvim_set_current_win(editor) -- nvim-tree focuses itself
      end
    end)
  end,
})

-- terminals inside nvim (⌘⇧Y) use Ghostty's colors, not the theme's
require "configs.ghostty_term"
-- translucent file tree over a solid editor, like Xcode's sidebar
require "configs.glass"
-- padding on the tree's right side, like on its left
require "configs.tree_padding"

-- `// MARK: - Title` drawn like Xcode (bold, with a line above)
require "configs.swift_marks"

-- yellow { } around the block the cursor is in
require "configs.scope_braces"

-- keep splits evenly sized (50/50) when the terminal is resized; windows with
-- a fixed width, like the file tree, keep theirs
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    local current = vim.api.nvim_get_current_tabpage()
    vim.cmd "tabdo wincmd ="
    vim.api.nvim_set_current_tabpage(current)
  end,
})
