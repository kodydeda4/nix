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
      -- don't unfold the tree to every file you open (search results etc.)
      opts.update_focused_file = { enable = false }
      opts.view = vim.tbl_deep_extend("force", opts.view or {}, { width = 60 })
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

  -- Xcode in nvim: build / run / test / debug on simulators and devices.
  -- <leader>i… ("iOS"; <leader>x is NvChad's close-buffer), plus ⌃T / ⌃G for
  -- scheme / device like in Zed. Needs xcode-build-server and xcbeautify (packages.nix).
  -- Run :checkhealth xcodebuild from a project root to see what's missing.
  {
    "wojciech-kulik/xcodebuild.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim", -- picker (NvChad's)
      "MunifTanjim/nui.nvim",
      "mfussenegger/nvim-dap",
    },
    ft = { "swift", "objc", "objcpp" },
    cmd = { "XcodebuildSetup", "XcodebuildPicker", "XcodebuildBuild", "XcodebuildBuildRun" },
    keys = {
      { "<leader>ii", "<cmd>XcodebuildPicker<cr>", desc = "Xcodebuild actions" },
      { "<leader>if", "<cmd>XcodebuildProjectManager<cr>", desc = "Xcodebuild project manager" },
      { "<leader>is", "<cmd>XcodebuildSetup<cr>", desc = "Xcodebuild set up project" },

      { "<leader>ib", "<cmd>XcodebuildBuild<cr>", desc = "Xcodebuild build" },
      { "<leader>ir", "<cmd>XcodebuildBuildRun<cr>", desc = "Xcodebuild build & run" },
      { "<leader>ix", "<cmd>XcodebuildCancel<cr>", desc = "Xcodebuild stop" },
      { "<C-t>", "<cmd>XcodebuildSelectScheme<cr>", desc = "Xcodebuild select scheme" },
      { "<C-g>", "<cmd>XcodebuildSelectDevice<cr>", desc = "Xcodebuild select device" },

      { "<leader>it", "<cmd>XcodebuildTest<cr>", desc = "Xcodebuild run tests" },
      { "<leader>it", "<cmd>XcodebuildTestSelected<cr>", mode = "v", desc = "Xcodebuild run selected tests" },
      { "<leader>iT", "<cmd>XcodebuildTestClass<cr>", desc = "Xcodebuild run test class" },
      { "<leader>i.", "<cmd>XcodebuildTestRepeat<cr>", desc = "Xcodebuild repeat last test run" },
      { "<leader>ie", "<cmd>XcodebuildTestExplorerToggle<cr>", desc = "Xcodebuild test explorer" },

      { "<leader>il", "<cmd>XcodebuildToggleLogs<cr>", desc = "Xcodebuild logs" },
      { "<leader>ic", "<cmd>XcodebuildToggleCodeCoverage<cr>", desc = "Xcodebuild code coverage" },
      { "<leader>iC", "<cmd>XcodebuildShowCodeCoverageReport<cr>", desc = "Xcodebuild coverage report" },
      { "<leader>iq", "<cmd>Telescope quickfix<cr>", desc = "Xcodebuild errors (quickfix)" },
      { "<leader>ia", "<cmd>XcodebuildCodeActions<cr>", desc = "Xcodebuild code actions" },

      -- SwiftUI previews (needs the XcodebuildNvimPreview package in the app)
      { "<leader>ip", "<cmd>XcodebuildPreviewGenerateAndShow<cr>", desc = "Xcodebuild preview" },
      { "<leader>iP", "<cmd>XcodebuildPreviewGenerateAndShow hotReload<cr>", desc = "Xcodebuild preview (hot reload)" },
      { "<leader>i<cr>", "<cmd>XcodebuildPreviewToggle<cr>", desc = "Xcodebuild toggle preview" },

      -- debugging (Xcode's lldb-dap)
      { "<leader>id", function() require("xcodebuild.integrations.dap").build_and_debug() end, desc = "Xcodebuild build & debug" },
      { "<leader>iD", function() require("xcodebuild.integrations.dap").debug_without_build() end, desc = "Xcodebuild debug without building" },
      { "<leader>iB", function() require("xcodebuild.integrations.dap").toggle_breakpoint() end, desc = "Xcodebuild toggle breakpoint" },
      { "<leader>iX", function() require("xcodebuild.integrations.dap").terminate_session() end, desc = "Xcodebuild stop debugging" },
    },
    config = function()
      require("xcodebuild").setup {
        -- keep per-project settings in nvim's data dir instead of a .nvim/
        -- folder in the repo
        project_config = { store_in_project_dir = false },
        commands = {
          extra_build_args = {
            "-parallelizeTargets",
            -- hot reload (<leader>iP) with InjectionNext: it needs the compile
            -- commands logged and the app linked so code can be swapped.
            -- Set here, not in the project, so team builds are unaffected.
            "EMIT_FRONTEND_COMMAND_LINES=YES",
            "OTHER_LDFLAGS=$(inherited) -Xlinker -interposable",
          },
        },
      }
      require("xcodebuild.integrations.dap").setup()
    end,
  },

  -- snippets: NvChad's setup, plus the espanso Swift snippets, expanded as
  -- you type (configs/espanso_snippets.lua)
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      require("luasnip").config.set_config(opts)
      require "nvchad.configs.luasnip"
      require "configs.espanso_snippets"
    end,
  },

  -- images in nvim via ghostty's kitty graphics protocol (also through tmux,
  -- see allow-passthrough in tmux.conf): xcodebuild.nvim's SwiftUI previews,
  -- and images inside markdown files
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      image = { enabled = true },
      -- vim.notify as corner popups: xcodebuild.nvim's progress messages
      -- ("Generating Preview...") otherwise stop nvim at "Press ENTER"
      notifier = { enabled = true },
    },
  },

  -- debugger UI for xcodebuild.nvim (opens with the debug session)
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    lazy = true,
    config = function()
      local dap, dapui = require "dap", require "dapui"
      dapui.setup()
      dap.listeners.after.event_initialized.dapui = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui = function() dapui.close() end
      dap.listeners.before.event_exited.dapui = function() dapui.close() end
    end,
  },
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    config = function()
      require "dapui" -- load the UI along with the debugger
    end,
  },

  -- syntax highlighting. nvim-treesitter's `main` branch (what lazy-lock pins)
  -- ignores NvChad's `ensure_installed` and doesn't turn highlighting on by
  -- itself, so install the parsers and start treesitter per filetype here.
  -- Parsers need the tree-sitter CLI and a C compiler (both on PATH via nix).
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- the main branch doesn't support lazy-loading
    build = ":TSUpdate",
    config = function()
      pcall(function()
        dofile(vim.g.base46_cache .. "syntax")
        dofile(vim.g.base46_cache .. "treesitter")
      end)

      require("nvim-treesitter").install {
        "swift",
        "lua", "luadoc", "printf", "vim", "vimdoc",
        "bash", "json", "markdown", "markdown_inline", "nix", "rust", "toml", "yaml",
      }

      -- highlight (and indent) every filetype that has an installed parser
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          if pcall(vim.treesitter.start, args.buf) then
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })
    end,
  },
}
