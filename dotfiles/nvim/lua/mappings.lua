require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- vim-tmux-navigator (overrides NvChad defaults)
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
-- Ctrl+J / Ctrl+K: next / previous tab (buffer), like in Zed
map("n", "<C-j>", function()
  require("nvchad.tabufline").next()
end, { desc = "next tab" })
map("n", "<C-k>", function()
  require("nvchad.tabufline").prev()
end, { desc = "previous tab" })
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

-- Space e: show / hide the file tree (NvChad's only focuses it)
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "toggle file tree" })

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

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
