require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- vim-tmux-navigator (overrides NvChad defaults)
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
-- Ctrl+J / Ctrl+K: next / previous tab (buffer), like in Zed. With the ⌘⇧Y
-- terminal open below, Ctrl+J moves down into it and Ctrl+K moves back up to
-- the editor instead.
local function is_term(win)
  return vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal"
end
local function win_toward(dir)
  local nr = vim.fn.winnr(dir)
  return nr ~= vim.fn.winnr() and vim.fn.win_getid(nr) or nil
end

map("n", "<C-j>", function()
  local below = win_toward "j"
  if below and is_term(below) and not is_term(0) then
    vim.api.nvim_set_current_win(below)
    vim.cmd.startinsert()
  else
    require("nvchad.tabufline").next()
  end
end, { desc = "next tab / go to terminal below" })
map({ "n", "t" }, "<C-k>", function()
  local above = win_toward "k"
  if is_term(0) and above then
    vim.cmd.stopinsert() -- leave terminal mode so the editor is in normal mode
    vim.api.nvim_set_current_win(above)
  elseif vim.fn.mode() == "t" then
    vim.api.nvim_feedkeys(vim.keycode "<C-k>", "n", false) -- pass it to the shell
  else
    require("nvchad.tabufline").prev()
  end
end, { desc = "previous tab / back to editor" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")

-- ⌃⌘J / ⌃⌘H / ⌃⌘L: go to definition / back / forward, like Zed.
-- Ghostty sends them as ⌥⇧J / ⌥⇧H / ⌥⇧L (terminals never see ⌘).
-- Duplicate results count as one and jump straight there; several real
-- candidates (overloads, protocol implementations) open a Telescope picker
-- instead of the quickfix list.
map("n", "<M-J>", function()
  vim.lsp.buf.definition {
    on_list = function(list)
      local seen, items = {}, {}
      for _, item in ipairs(list.items) do
        local key = item.filename .. ":" .. item.lnum
        if not seen[key] then
          seen[key] = true
          table.insert(items, item)
        end
      end
      if #items == 1 then
        vim.cmd "normal! m'" -- so ⌃⌘H comes back here
        if vim.fs.normalize(items[1].filename) ~= vim.fs.normalize(vim.api.nvim_buf_get_name(0)) then
          vim.cmd.edit(vim.fn.fnameescape(items[1].filename))
        end
        vim.api.nvim_win_set_cursor(0, { items[1].lnum, math.max(items[1].col - 1, 0) })
        vim.cmd "normal! zz"
      else
        require("telescope.builtin").lsp_definitions()
      end
    end,
  }
end, { desc = "LSP go to definition" })
map("n", "<M-H>", "<C-o>", { desc = "jump back" })
map("n", "<M-L>", "<C-i>", { desc = "jump forward" })

-- Space t h: theme picker, with Ctrl+J / Ctrl+K to move down / up. Enter saves
-- the theme for the current macOS mode (light or dark; configs/appearance.lua).
map("n", "<leader>th", function()
  require("nvchad.themes").open {
    mappings = function(buf)
      local api = require "nvchad.themes.api"
      local state = require "nvchad.themes.state"
      vim.keymap.set("i", "<C-j>", api.move_down, { buffer = buf })
      vim.keymap.set("i", "<C-k>", api.move_up, { buffer = buf })
      vim.keymap.set({ "i", "n" }, "<cr>", function()
        state.confirmed = true
        require("configs.appearance").save_pick(state.themes_shown[state.index])
        require("volt").close()
      end, { buffer = buf })
    end,
  }
end, { desc = "theme picker" })

-- Space t c: code theme picker, the syntax colors for everything but Swift
-- (the rest stays the theme above). Each theme shows on your code as you move
-- to it; Enter saves it for the current mode (light or dark), Esc goes back.
map("n", "<leader>tc", function()
  local code_syntax = require "configs.code_syntax"
  local items = {}
  for _, name in ipairs(require("nvchad.utils").list_themes()) do
    if not name:match "^xcode" then
      table.insert(items, { text = name })
    end
  end
  Snacks.picker {
    title = "Code theme",
    items = items,
    format = "text",
    layout = { preset = "select" },
    on_change = function(_, item)
      if item then
        code_syntax.build(item.text)
        code_syntax.update_all()
      end
    end,
    confirm = function(picker, item)
      if item then
        require("configs.appearance").save_code_pick(item.text)
      end
      picker:close()
    end,
    on_close = function()
      vim.schedule(function()
        code_syntax.build() -- the saved one (the new pick, or back to the old)
        code_syntax.update_all()
      end)
    end,
  }
end, { desc = "code theme picker" })

-- Space e: show / hide the file tree (NvChad's only focuses it)
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "toggle file tree" })

-- ⌘0 (Ghostty sends ⌥⇧E): show / hide the file tree, like Xcode's navigator
map("n", "<M-E>", "<cmd>NvimTreeToggle<cr>", { desc = "toggle file tree" })

-- ⌘⇧J (Ghostty sends ⌥⇧R): show the current file in the file tree and focus it, like Xcode
map("n", "<M-R>", function()
  require("nvim-tree.api").tree.find_file { open = true, focus = true }
end, { desc = "reveal file in tree" })

-- ⌘> (Ghostty sends ⌥>): fold / unfold the whole file. Folding keeps top-level
-- types open and collapses what's inside them, like Xcode's Fold Methods & Functions.
map("n", "<M->>", function()
  vim.wo.foldlevel = vim.wo.foldlevel > 1 and 1 or 99
end, { desc = "toggle folding for the file" })

-- ⌘< (Ghostty sends ⌥<): fold / unfold the scope the cursor is in
map("n", "<M-<>", "za", { desc = "toggle fold for the current scope" })

-- Swift symbol search (types, functions, properties, enum cases) from sourcekit,
-- like Xcode's Open Quickly. ⌘⇧O (Ghostty sends ⌥⇧S) or Space f s: whole
-- project; Space f d: this file. (configs/swift_symbols.lua)
map("n", "<M-S>", function() require("configs.swift_symbols").project() end, { desc = "open quickly (symbols)" })
map("n", "<leader>fs", function() require("configs.swift_symbols").project() end, { desc = "find symbol in project" })
map("n", "<leader>fd", function() require("configs.swift_symbols").file() end, { desc = "find symbol in this file" })

-- ⌘⇧Y (Ghostty sends ⌥⇧Y): show / hide a terminal below the editor, like
-- Xcode's debug area. Works from inside the terminal too, so it hides itself.
map({ "n", "t" }, "<M-Y>", function()
  require("nvchad.term").toggle { pos = "sp", id = "bottomTerm" }
end, { desc = "toggle terminal below" })

-- ⌃I (Ghostty sends ⌥⇧I): format the selected lines, or the current line with
-- nothing selected, like Xcode's Re-Indent. Uses the file's formatter
-- (configs/conform.lua); ones without range support (rustfmt) format the
-- file and conform keeps only the changes inside the range.
map({ "n", "v" }, "<M-I>", function()
  local range
  if vim.fn.mode() == "n" then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    range = { start = { row, 0 }, ["end"] = { row, #vim.api.nvim_get_current_line() } }
  end
  require("conform").format { lsp_format = "fallback", range = range }
end, { desc = "format selection / line" })

-- ⌘A (Ghostty sends ⌥⇧A): select the whole file, so ⌃I formats all of it
map({ "n", "v", "i" }, "<M-A>", "<Esc>ggVG", { desc = "select all" })

-- Ctrl+E: split side by side (same as Ctrl+E in tmux outside nvim)
map("n", "<C-e>", "<cmd>vsplit<cr>", { desc = "split window side by side" })

-- Space t i: show / hide the indent guide lines, in the editor and the file
-- tree, remembered across restarts (a flag file the indent-blankline and
-- nvim-tree setups read, plugins/init.lua)
map("n", "<leader>ti", function()
  vim.cmd "IBLToggle"
  local on = require("ibl.config").get_config(0).enabled
  local flag = vim.fn.stdpath "state" .. "/indent-lines-off"
  if on then
    vim.fn.delete(flag)
  else
    vim.fn.writefile({}, flag)
  end
  -- nvim-tree reads this setting each time it draws
  local ok, tree_config = pcall(require, "nvim-tree.config")
  if ok and tree_config.g then
    tree_config.g.renderer.indent_markers.enable = on
    pcall(function()
      require("nvim-tree.api").tree.reload()
    end)
  end
end, { desc = "toggle indent lines" })

-- Space t b: see-through editor background, so Ghostty's glass shows behind the
-- code too, not just the file tree. Remembered across restarts (a flag file
-- configs/xcode_theme.lua and configs/ghostty_term.lua read). Popups, the
-- current line and selections stay solid.
map("n", "<leader>tb", function()
  local flag = vim.fn.stdpath "state" .. "/editor-glass"
  if vim.fn.filereadable(flag) == 1 then
    vim.fn.delete(flag)
  else
    vim.fn.writefile({}, flag)
  end
  -- the theme files read the flag when they load: drop the loaded ones so
  -- base46 rebuilds the theme from them
  for name in pairs(package.loaded) do
    if name:match "^themes%." then
      package.loaded[name] = nil
    end
  end
  require("base46").load_all_highlights()
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false }) -- re-runs options.lua's bar colors
end, { desc = "toggle transparent background" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
