require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- vim-tmux-navigator (overrides NvChad defaults)
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
map("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
map("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
map("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")

-- Ctrl+E: split side by side (same as Ctrl+E in tmux outside nvim)
map("n", "<C-e>", "<cmd>vsplit<cr>", { desc = "split window side by side" })

-- Space t b: toggle transparent background (base46's built-in toggle)
map("n", "<leader>tb", function()
  require("base46").toggle_transparency()
end, { desc = "toggle transparency" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
