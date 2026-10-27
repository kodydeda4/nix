-- rsx! (Dioxus) highlighting, like Zed's (zed/rsx/). nvim-treesitter's Rust
-- injections reparse every macro body as Rust, and rsx! isn't, so it came out
-- broken. Instead each rsx! macro becomes its own tree in an `rsx` language:
-- the Rust parser under another name, with queries/rsx/highlights.scm.

local parser = vim.api.nvim_get_runtime_file("parser/rust.so", false)[1]
if not parser then
  return
end
vim.treesitter.language.add("rsx", { path = parser, symbol_name = "rust" })

-- nvim-treesitter's Rust injections, with rsx! taken out of the "reparse as
-- Rust" rule and given to rsx instead. Patched here rather than copied, so it
-- follows nvim-treesitter's updates.
local files = vim.treesitter.query.get_files("rust", "injections")
local text = table.concat(vim.fn.readfile(files[1]), "\n")
local patched, n = text:gsub('%(#not%-any%-of%? @_macro_name "slint" "html" "json" "xml"%)',
  '(#not-any-of? @_macro_name "slint" "html" "json" "xml" "rsx")')
if n ~= 1 then
  vim.notify("rsx.lua: nvim-treesitter's Rust injections changed, rsx! left as is", vim.log.levels.WARN)
  return
end
vim.treesitter.query.set("rust", "injections", patched .. [[

((macro_invocation
  macro: [
    (scoped_identifier
      name: (_) @_macro_name)
    (identifier) @_macro_name
  ]) @injection.content
  (#eq? @_macro_name "rsx")
  (#set! injection.language "rsx")
  (#set! injection.include-children))
]])
