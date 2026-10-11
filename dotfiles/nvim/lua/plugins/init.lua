return {
  {
    "christoomey/vim-tmux-navigator",
    lazy = false,
  },

  -- file tree: Enter opens the file in the split you came from, instead of
  -- asking which window to use (the letter "window picker")
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      opts.actions = vim.tbl_deep_extend("force", opts.actions or {}, {
        open_file = { window_picker = { enable = false } },
      })
      return opts
    end,
  },

  -- multiple cursors, like Xcode's Select Column Down/Up:
  -- ⌥⌘J / ⌥⌘K (Ghostty sends them as <M-j>/<M-k>) add a cursor below/above.
  -- Every cursor runs your real vim commands (ci", dw, A, ., counts, ...),
  -- no separate mode or prompts. <Esc> in normal mode removes the extra cursors.
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    lazy = false,
    config = function()
      local mc = require "multicursor-nvim"
      mc.setup()

      vim.keymap.set({ "n", "x" }, "<M-j>", function() mc.lineAddCursor(1) end, { desc = "Add cursor below" })
      vim.keymap.set({ "n", "x" }, "<M-k>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above" })

      -- these keys only apply while there are extra cursors
      mc.addKeymapLayer(function(layerSet)
        layerSet("n", "<esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end)
      end)
    end,
  },

  -- lazygit in a floating window: <leader>lg (space l g)
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
    },
  },

  {
    "stevearc/conform.nvim",
    event = "BufWritePre", -- load before the first save so format-on-save runs
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
