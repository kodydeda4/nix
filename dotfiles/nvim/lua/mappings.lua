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

-- Space e: show / hide the file tree (NvChad's only focuses it)
map("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "toggle file tree" })

-- ⌘⇧J (Ghostty sends ⌥⇧R): show the current file in the file tree and focus it, like Xcode
map("n", "<M-R>", function()
  require("nvim-tree.api").tree.find_file { open = true, focus = true }
end, { desc = "reveal file in tree" })

-- Ctrl+E: split side by side (same as Ctrl+E in tmux outside nvim)
map("n", "<C-e>", "<cmd>vsplit<cr>", { desc = "split window side by side" })

-- Space t b: toggle transparent background (base46's built-in toggle)
map("n", "<leader>tb", function()
  require("base46").toggle_transparency()
end, { desc = "toggle transparency" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
