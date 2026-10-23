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
      -- no 2-column sign column on the left of the tree
      opts.view = vim.tbl_deep_extend("force", opts.view or {}, { width = 50, signcolumn = "no" })
      -- Xcode-style icons for Swift packages and .xcodeproj (configs/xcode_tree.lua)
      opts.renderer = opts.renderer or {}
      opts.renderer.highlight_git = false -- names stay white; git status icons remain
      -- the tree's indent lines follow Space t i, like the editor's (mappings.lua)
      opts.renderer.indent_markers = vim.tbl_extend("force", opts.renderer.indent_markers or {}, {
        enable = vim.fn.filereadable(vim.fn.stdpath "state" .. "/indent-lines-off") == 0,
      })
      opts.renderer.decorators = {
        "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",
        require "configs.xcode_tree",
        "Cut",
      }
      -- Space marks items for multi-select (and moves down); d / D then move all
      -- marked items (or the one under the cursor) to the Trash, and u undoes the
      -- last delete / rename / move / create (configs/tree_undo.lua).
      -- Space fires right away in the tree (it's the leader key everywhere else).
      opts.on_attach = function(buf)
        local api = require "nvim-tree.api"
        api.config.mappings.default_on_attach(buf)
        local function map(lhs, fn, desc)
          vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = "nvim-tree: " .. desc })
        end
        local undo = require "configs.tree_undo"
        undo.setup()
        local function delete()
          local paths = vim.tbl_map(function(node) return node.absolute_path end, api.marks.list())
          if #paths == 0 then
            local node = api.tree.get_node_under_cursor()
            if not node or node.name == ".." then
              return
            end
            paths = { node.absolute_path }
          end
          undo.delete(paths)
        end
        map("<Space>", function()
          api.marks.toggle()
          vim.cmd "normal! j"
        end, "mark for multi-select")
        map("d", delete, "delete (marked items) to the Trash")
        map("D", delete, "delete (marked items) to the Trash")
        map("u", undo.undo, "undo last file operation")
        map("<Esc>", api.marks.clear, "clear marks")
      end
      return opts
    end,
  },

  -- current scope: no highlighted first line (its brackets turn yellow instead, configs/scope_braces.lua)
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = function(_, opts)
      opts.scope = vim.tbl_deep_extend("force", opts.scope or {}, { show_start = false, show_end = false })
      -- Space t i's choice is remembered across restarts (mappings.lua)
      opts.enabled = vim.fn.filereadable(vim.fn.stdpath "state" .. "/indent-lines-off") == 0
      return opts
    end,
  },

  -- Swift file icons in Xcode's Swift-logo orange, Package files like Xcode
  {
    "nvim-tree/nvim-web-devicons",
    opts = function(_, opts)
      opts.override_by_extension = vim.tbl_extend("force", opts.override_by_extension or {}, {
        swift = { icon = vim.fn.nr2char(0xF06E5), color = "#ea9046", name = "Swift" }, -- 󰛥
      })
      -- Package.swift / Package.resolved like in Xcode's navigator
      opts.override_by_filename = vim.tbl_extend("force", opts.override_by_filename or {}, {
        ["package.swift"] = { icon = vim.fn.nr2char(0xF06E5), color = "#d6b47f", name = "SwiftPackage" },
        ["package.resolved"] = { icon = vim.fn.nr2char(0xF0626), color = "#f25c54", name = "SwiftPackageResolved" }, -- 󰘦 {}
      })
      return opts
    end,
  },

  -- leader-key popup: don't shrink to a thin strip when a group has few keys.
  -- The empty rows that leaves take the popup's own background (they showed
  -- the editor's End-of-Buffer color: a black band across the popup).
  {
    "folke/which-key.nvim",
    opts = function(_, opts)
      opts.win = vim.tbl_deep_extend("force", opts.win or {}, {
        height = { min = 10, max = 25 },
        -- which-key's own mapping, plus End-of-Buffer
        wo = {
          winhighlight = "Normal:WhichKeyNormal,FloatBorder:WhichKeyBorder,FloatTitle:WhichKeyTitle,EndOfBuffer:WhichKeyNormal",
        },
      })
      return opts
    end,
  },

  -- Ctrl+J / Ctrl+K move down / up in pickers (live grep, find files, ...)
  {
    "nvim-telescope/telescope.nvim",
    opts = function(_, opts)
      local actions = require "telescope.actions"
      opts.defaults.mappings.i = vim.tbl_extend("force", opts.defaults.mappings.i or {}, {
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
      })
      -- also after Esc (normal mode in the picker)
      opts.defaults.mappings.n = vim.tbl_extend("force", opts.defaults.mappings.n or {}, {
        ["<C-j>"] = actions.move_selection_next,
        ["<C-k>"] = actions.move_selection_previous,
      })
      return opts
    end,
  },

  -- ⌃M (Ghostty sends ⌥M): Xcode's "Format to Multiple Lines". Puts each
  -- argument / parameter / element of the (...), [...] or {...} under the cursor
  -- on its own line; again joins them back onto one line.
  {
    "echasnovski/mini.splitjoin",
    version = false,
    keys = { { "<M-m>", desc = "format to multiple lines / join" } },
    config = function()
      local splitjoin = require "mini.splitjoin"
      splitjoin.setup { mappings = { toggle = "", split = "", join = "" } }
      -- matching bracket of the one at row / col (1-based), as { row, col }
      local function partner(row, col, open, close)
        local view = vim.fn.winsaveview()
        vim.api.nvim_win_set_cursor(0, { row, col - 1 })
        local pos = vim.fn.searchpairpos(open, "", close, "nW")
        vim.fn.winrestview(view)
        return pos
      end

      -- { body } on one line <-> body on its own line (computed properties,
      -- closures, one-line functions). Only a single-line body joins back.
      local function toggle_braces(row, open)
        local close = partner(row, open, "{", "}")
        local line = vim.api.nvim_get_current_line()
        local indent = line:match "^%s*"
        if close[1] == row then
          local body = vim.trim(line:sub(open + 1, close[2] - 1))
          if body == "" then
            return
          end
          local unit = vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t"
          vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
            (line:sub(1, open):gsub("%s+$", "")),
            indent .. unit .. body,
            indent .. line:sub(close[2]),
          })
        elseif close[1] == row + 2 and close[2] == #vim.fn.getline(row + 2):match "^%s*" + 1 then
          local body = vim.trim(vim.fn.getline(row + 1))
          local rest = vim.trim(vim.fn.getline(row + 2))
          vim.api.nvim_buf_set_lines(0, row - 1, row + 2, false, {
            line:sub(1, open) .. " " .. body .. " " .. rest,
          })
        end
      end

      vim.keymap.set("n", "<M-m>", function()
        -- Only brackets that open on the cursor's line, like Xcode: the
        -- innermost one around the cursor, else the first one after it (never
        -- an enclosing block from lines above). ( ) and [ ] split one item per
        -- line; { } moves its body onto its own line.
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        local open, kind
        for _, pair in ipairs { { "(", ")" }, { "\\[", "\\]" }, { "{", "}" } } do
          local pos = vim.fn.searchpairpos(pair[1], "", pair[2], "bcnW", "", row)
          if pos[1] == row and (not open or pos[2] > open) then
            open, kind = pos[2], pair[1]
          end
        end
        if not open then
          -- the first one after the cursor, skipping empty () / [] (func f() {)
          local line = vim.api.nvim_get_current_line()
          local from = col + 1
          while true do
            open = line:find("[%(%[{]", from)
            kind = open and line:sub(open, open)
            if not open or kind == "{" or not line:sub(open):match "^[%(%[]%s*[%)%]]" then
              break
            end
            from = open + 1
          end
        end
        if not open then
          return
        elseif kind == "{" then
          toggle_braces(row, open)
        else
          splitjoin.toggle { position = { line = row, col = open + 1 } }
        end
      end, { desc = "format to multiple lines / join" })
    end,
  },

  -- ...and in the completion menu, blink.cmp (NvChad's setup, replacing nvim-cmp)
  { import = "nvchad.blink.lazyspec" },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.keymap["<C-j>"] = { "select_next", "fallback" }
      opts.keymap["<C-k>"] = { "select_prev", "fallback" }
      -- arrows move through the suggestions while they're open, the cursor otherwise
      opts.keymap["<Down>"] = { "select_next", "fallback" }
      opts.keymap["<Up>"] = { "select_prev", "fallback" }

      -- icon, then the name: no kind name on the right, which got cut off in
      -- narrow windows (the icon's color already says what it is)
      opts.completion.menu.draw.columns = { { "kind_icon" }, { "label" } }

      -- the docs: beside the menu when there are 50 columns free there,
      -- otherwise above / below it (blink's default) instead of squeezed into a
      -- sliver, and room for a readable paragraph or signature
      opts.completion.documentation.window = {
        border = "single",
        max_width = 80,
        max_height = 30,
      }

      -- Rust: snippets above rust-analyzer's items, so typing a Dioxus hook's
      -- full name offers its example first (configs/dioxus_snippets.lua)
      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.snippets = {
        -- ...but none right after `::` or `.`, where they'd bury the enum
        -- cases / associated functions / methods rust-analyzer offers
        should_show_items = function(ctx)
          return not ctx.line:sub(1, ctx.bounds.start_col - 1):match "[:.]$"
        end,
        transform_items = function(_, items)
          if vim.bo.filetype == "rust" then
            for _, item in ipairs(items) do
              item.score_offset = (item.score_offset or 0) + 100
            end
          end
          return items
        end,
      }
      return opts
    end,
  },

  -- multiple cursors, like Xcode's Select Column Down/Up:
  -- ⌥⌘J / ⌥⌘K (Ghostty sends them as <M-n>/<M-p>) add a cursor below/above.
  -- Every cursor runs your real vim commands (ci", dw, A, ., counts, ...),
  -- no separate mode or prompts. <Esc> in normal mode removes the extra cursors.
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    lazy = false,
    config = function()
      local mc = require "multicursor-nvim"
      mc.setup()

      vim.keymap.set({ "n", "x" }, "<M-n>", function() mc.lineAddCursor(1) end, { desc = "Add cursor below" })
      vim.keymap.set({ "n", "x" }, "<M-p>", function() mc.lineAddCursor(-1) end, { desc = "Add cursor above" })

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
  -- you type (configs/espanso_snippets.lua), and Dioxus hook examples in the
  -- completion menu (configs/dioxus_snippets.lua)
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      require("luasnip").config.set_config(opts)
      require "nvchad.configs.luasnip"
      require "configs.espanso_snippets"
      require "configs.dioxus_snippets"
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
      -- prompts (file tree rename / new file / delete y/n, LSP rename...) as a
      -- popup instead of the command line at the bottom
      input = { enabled = true, expand = false },
      -- from the file tree: the prompt sits inside the sidebar, right under the
      -- item being renamed / created in, as wide as the tree; elsewhere (LSP
      -- rename...) near the top, centered
      styles = {
        input = (function()
          -- where the prompt goes, worked out once from the window it opened from
          local function place(win)
            if not win.xcode_place then
              local cur = vim.api.nvim_get_current_win()
              if vim.bo[vim.api.nvim_win_get_buf(cur)].filetype == "NvimTree" then
                local top, left = unpack(vim.fn.win_screenpos(cur))
                win.xcode_place = {
                  row = top - 1 + vim.fn.winline(),
                  col = left - 1,
                  width = vim.api.nvim_win_get_width(cur) - 2,
                }
              else
                win.xcode_place = { row = 2, col = math.floor((vim.o.columns - 62) / 2), width = 60 }
              end
            end
            return win.xcode_place
          end
          return {
            title_pos = "left",
            -- Esc cancels right away (snacks' default first leaves insert mode)
            keys = { i_esc = { "<esc>", { "cmp_close", "cancel" }, mode = "i", expr = true } },
            row = function(win) return place(win).row end,
            col = function(win) return place(win).col end,
            width = function(win) return place(win).width end,
          }
        end)(),
      },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      -- an icon per kind of prompt (snacks shows a pencil on all of them)
      local icon = function(code) return vim.fn.nr2char(code) .. " " end
      local icons = {
        { "^Create", icon(0xF067) }, -- plus
        { "^Delete", icon(0xF1F8), true }, -- trash, red (nvim-tree's "Remove", reworded above)
        { "^Trash", icon(0xF1F8), true },
        { "^Overwrite", icon(0xF071), true }, -- warning, red
        { "already exist", icon(0xF071), true },
      }

      -- neutral prompts (create, rename...): grey border and icon, plain title;
      -- deleting / overwriting: red while that prompt is open. Follows the theme.
      local function colors(red)
        local function fg(name) return vim.api.nvim_get_hl(0, { name = name, link = false }).fg end
        local danger = fg "DiagnosticError"
        vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = red and danger or fg "LineNr" })
        vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = red and danger or fg "@variable", bold = true })
        vim.api.nvim_set_hl(0, "SnacksInputIcon", { fg = red and danger or fg "@comment" })
        -- a solid popup (Normal has no background, for the glass sidebar)
        vim.api.nvim_set_hl(0, "SnacksInputNormal", { link = "NormalFloat" })
      end
      colors()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = function() colors() end })
      local input = require "snacks.input"
      local show = input.input
      input.input = function(o, on_confirm)
        o = vim.deepcopy(o or {})
        -- nvim-tree's "Remove x? y/N:" reads as "Delete x? Y/N" (the answer is
        -- lowercased, so Y works)
        o.prompt = (o.prompt or ""):gsub("^Remove ", "Delete "):gsub(" [yY]/[nN]: $", " Y/N: ")
        -- multi-select (Space in the tree): "Remove bookmarked ?" -> "Delete 3 items?"
        local verb = o.prompt:match "^(%a+) bookmarked %?"
        if verb then
          local n = #require("nvim-tree.api").marks.list()
          o.prompt = o.prompt:gsub("^%a+ bookmarked %?", ("%s %d item%s?"):format(verb == "Remove" and "Delete" or verb, n, n == 1 and "" or "s"))
        end
        for _, rule in ipairs(icons) do
          if (o.prompt or ""):find(rule[1]) then
            o.icon = rule[2]
            if rule[3] then
              colors(true)
              local done = on_confirm
              on_confirm = function(...)
                colors() -- back to neutral (also runs on cancel)
                return done(...)
              end
            end
            break
          end
        end
        -- leaving the prompt (clicking or jumping back to the editor) cancels it
        local answered = false
        local reply = on_confirm
        on_confirm = function(...)
          answered = true
          return reply(...)
        end
        local win = show(o, on_confirm)
        if win then
          win:on("WinLeave", function()
            vim.schedule(function()
              if not answered and win:valid() then
                win:execute "cancel"
              end
            end)
          end, { buf = true })
        end
        return win
      end
      vim.ui.input = input.input
    end,
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

  -- `:` opens the command line as a box in the middle of the screen, instead
  -- of on its bottom row. Only
  -- the command line and its messages: hover, signature help and LSP progress
  -- stay as they were.
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdline = {
        view = "cmdline_popup",
        -- plain text (no syntax colors) and no title on every kind of prompt
        format = {
          cmdline = { lang = false, title = "" },
          search_down = { lang = false, title = "" },
          search_up = { lang = false, title = "" },
          filter = { lang = false, title = "" },
          lua = { lang = false, title = "" },
          help = { lang = false, title = "" },
        },
      },
      -- "written", errors, etc.: small, in the bottom-right corner
      messages = { view = "mini", view_error = "mini", view_warn = "mini" },
      notify = { enabled = false },
      lsp = {
        progress = { enabled = false }, -- the status bar shows it
        hover = { enabled = false },
        signature = { enabled = false },
        message = { enabled = false },
      },
      presets = { long_message_to_split = true },
      views = {
        cmdline_popup = {
          relative = "editor", -- centered on the whole screen
          position = { row = "50%", col = "50%" },
          size = { width = "50%" },
        },
      },
    },
  },
}
