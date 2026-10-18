-- Formatters per file type. Run with Space f m, and automatically on save.
-- All indent with tabs (2 wide) except nix.
-- The programs come from nix (flake.nix): alejandra, stylua, prettier, shfmt.
-- rustfmt comes from rustup; swiftformat (nicklockwood/SwiftFormat) from nix.
local prettier = { "prettier" } -- uses a project's own prettier (node_modules) when present

local options = {
  formatters_by_ft = {
    nix = { "alejandra" },
    lua = { "stylua" },
    javascript = prettier,
    javascriptreact = prettier,
    typescript = prettier,
    typescriptreact = prettier,
    svelte = prettier,
    json = prettier,
    jsonc = prettier,
    css = prettier,
    scss = prettier,
    html = prettier,
    markdown = prettier,
    yaml = prettier,
    sh = { "shfmt" },
    bash = { "shfmt" },
    rust = { "rustfmt", "dx_rsx" },
    swift = { "swiftformat" },
  },

  -- tabs everywhere (2 wide), matching options.lua. Nix is the exception:
  -- alejandra has no tab option (see note in flake.nix's formatter).
  formatters = {
    prettier = { prepend_args = { "--use-tabs", "--tab-width", "2" } },
    stylua = { prepend_args = { "--indent-type", "Tabs", "--indent-width", "2" } },
    rustfmt = { prepend_args = { "--config", "hard_tabs=true,tab_spaces=2" } },
    -- Dioxus rsx! { ... } blocks, which rustfmt leaves alone: `dx fmt` (the
    -- Dioxus CLI), only in files that use rsx!. From stdin it always indents
    -- with 4 spaces, so each 4 leading columns become a tab afterwards, on the
    -- lines it rewrote (lines it passed through untouched, like multi-line
    -- strings, keep their spaces).
    dx_rsx = {
      meta = { description = "Dioxus rsx! formatter (dx fmt), indented with tabs" },
      condition = function(_, ctx)
        if vim.fn.executable "dx" == 0 then
          return false
        end
        for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
          if line:find("rsx!", 1, true) then
            return true
          end
        end
        return false
      end,
      format = function(_, ctx, lines, callback)
        local input = table.concat(lines, "\n") .. "\n"
        vim.system({ "dx", "fmt", "-f", "-" }, { stdin = input, cwd = ctx.dirname, text = true }, vim.schedule_wrap(function(out)
          if out.code ~= 0 then
            return callback("dx fmt failed: " .. vim.trim(out.stderr or ""))
          end
          local unchanged = {}
          for _, line in ipairs(lines) do
            unchanged[line] = true
          end
          local formatted = vim.split((out.stdout:gsub("\n$", "")), "\n", { plain = true })
          for i, line in ipairs(formatted) do
            if not unchanged[line] then
              local indent, rest = line:match "^([ \t]*)(.*)$"
              local cols = 0
              for c in indent:gmatch "." do
                cols = c == "\t" and cols - cols % 4 + 4 or cols + 1
              end
              formatted[i] = string.rep("\t", math.floor(cols / 4)) .. string.rep(" ", cols % 4) .. rest
            end
          end
          callback(nil, formatted)
        end))
      end,
    },
    -- SwiftFormat, same tool as scripts/fpr: a repo's .swiftformat wins; files
    -- without one fall back to swiftformat-default (tabs) in this config dir
    swiftformat = {
      args = function(_, ctx)
        local args = { "--stdinpath", ctx.filename }
        if not vim.fs.find(".swiftformat", { upward = true, path = ctx.dirname })[1] then
          vim.list_extend(args, { "--config", vim.fn.stdpath "config" .. "/swiftformat-default" })
        end
        return args
      end,
    },
    -- shfmt follows nvim's own setting (expandtab off = tabs)
  },

  format_on_save = {
    timeout_ms = 2000,
    lsp_format = "fallback", -- no formatter listed? use the language server's
  },
}

return options
