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
    rust = { "rustfmt" },
    swift = { "swiftformat" },
  },

  -- tabs everywhere (2 wide), matching options.lua. Nix is the exception:
  -- alejandra has no tab option (see note in flake.nix's formatter).
  formatters = {
    prettier = { prepend_args = { "--use-tabs", "--tab-width", "2" } },
    stylua = { prepend_args = { "--indent-type", "Tabs", "--indent-width", "2" } },
    rustfmt = { prepend_args = { "--config", "hard_tabs=true,tab_spaces=2" } },
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
