-- Dumps the colors nvim really uses, for build.py to turn into the Zed theme.
-- Run by build.py inside a headless nvim with your full config:
--   nvim --headless "+luafile zed/xcode/dump.lua" <out.json>
--
-- Loads each base46 theme into this nvim's memory only (the base46 cache on
-- disk is left alone), then writes, for light and dark:
--   swift: the style of every highlight group nvim uses for Swift (tree-sitter
--     captures, sourcekit's @lsp groups, lspconfig.lua's paints, SwiftMark)
--   code: other languages' syntax colors (configs/code_syntax.lua's theme)
-- plus where the Swift parser and queries live, for sourcekit.lua.

local out_path = vim.fn.argv(0)

-- sourcekit-lsp's semantic token legend
local types = {
  "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter",
  "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword",
  "modifier", "comment", "string", "number", "regexp", "operator", "decorator", "bracket",
  "label", "concept", "unknown", "identifier",
}
local modifiers = {
  "declaration", "definition", "readonly", "static", "deprecated", "abstract", "async",
  "modification", "documentation", "defaultLibrary", "deduced", "virtual", "dependentName",
  "usedAsMutableReference", "usedAsMutablePointer", "constructorOrDestructor", "userDefined",
  "functionScope", "classScope", "fileScope", "globalScope", "parameterLabel",
}

-- capture names Zed's other languages use, with the nvim group each one means
-- when nvim names it differently (the rest are the same name)
local zed_aliases = {
  ["comment.doc"] = "@comment.documentation",
  preproc = "@keyword.directive",
  enum = "@type",
  variant = "@constant",
  namespace = "@module",
  ["string.regex"] = "@string.regexp",
  ["string.special.symbol"] = "@string.special.symbol",
  link_text = "@markup.link.label",
  link_uri = "@markup.link.url",
  emphasis = "@markup.italic",
  ["emphasis.strong"] = "@markup.strong",
  title = "@markup.heading",
  ["text.literal"] = "@markup.raw",
  ["punctuation.list_marker"] = "@markup.list",
  tag = "@tag",
  embedded = "@none",
}

local function hex(n)
  return n and string.format("#%06x", n) or nil
end

-- the style nvim draws `name` with, in namespace `ns` (falling back to the
-- global one like a window namespace does), following nvim's fallback for
-- @groups: @a.b.c.swift -> @a.b.c -> @a.b -> @a
local function style(name, ns)
  local candidates, n = { name }, name
  while true do
    local parent = n:match "^(@.+)%.[^.]+$"
    if not parent then
      break
    end
    table.insert(candidates, parent)
    n = parent
  end
  for _, c in ipairs(candidates) do
    for _, space in ipairs(ns and { ns, 0 } or { 0 }) do
      local h = vim.api.nvim_get_hl(space, { name = c, link = false, create = false })
      if next(h) then
        local s = {
          fg = hex(h.fg),
          bg = hex(h.bg),
          bold = h.bold or nil,
          italic = h.italic or nil,
          underline = h.underline or nil,
          strikethrough = h.strikethrough or nil,
        }
        return next(s) and s or vim.NIL
      end
    end
  end
  return vim.NIL
end

-- loads base46 theme `theme` like nvim's startup does: nvim's default colors,
-- then every integration base46 compiles (the cache's file names)
local function apply(theme)
  local nvconfig = require "nvconfig"
  nvconfig.base46.theme = theme
  for mod in pairs(package.loaded) do
    if mod:match "^base46" or mod:match "^themes%." then
      package.loaded[mod] = nil
    end
  end
  local base46 = require "base46"
  vim.o.background = base46.get_theme_tb "type"
  vim.cmd "hi clear"
  for name, kind in vim.fs.dir(vim.g.base46_cache) do
    if kind == "file" and name ~= "colors" and name ~= "term" then
      for group, spec in pairs(base46.get_integration(name)) do
        pcall(vim.api.nvim_set_hl, 0, group, spec)
      end
    end
  end
  -- configs/swift_marks.lua
  local comment = vim.api.nvim_get_hl(0, { name = "@comment", link = false })
  vim.api.nvim_set_hl(0, "SwiftMark", { fg = comment.fg, bold = true })
end

local query = vim.treesitter.query.get("swift", "highlights")
local swift_groups = { "SwiftMark", "@operator", "@variable", "@lsp.type.property" }
for _, capture in ipairs(query.captures) do
  table.insert(swift_groups, "@" .. capture .. ".swift")
end
for _, t in ipairs(types) do
  table.insert(swift_groups, "@lsp.type." .. t .. ".swift")
  table.insert(swift_groups, "@lsp.type." .. t)
  table.insert(swift_groups, "@lsp.typemod." .. t .. ".defaultLibrary")
  for _, m in ipairs(modifiers) do
    table.insert(swift_groups, "@lsp.typemod." .. t .. "." .. m .. ".swift")
  end
end
for _, m in ipairs(modifiers) do
  table.insert(swift_groups, "@lsp.mod." .. m .. ".swift")
end

-- every capture name nvim-treesitter's queries use, as the names Zed's
-- languages look up
local code_names = {}
for _, file in ipairs(vim.api.nvim_get_runtime_file("queries/*/highlights.scm", true)) do
  for capture in io.open(file):read("*a"):gmatch "@([%w_][%w_.]*)" do
    if not capture:match "^_" then
      code_names[capture] = "@" .. capture
    end
  end
end
for zed, nvim in pairs(zed_aliases) do
  code_names[zed] = nvim
end

local result = {
  parser = vim.api.nvim_get_runtime_file("parser/swift.so", false)[1],
  query_files = vim.treesitter.query.get_files("swift", "highlights"),
  sourcekit_legend = { tokenTypes = types, tokenModifiers = modifiers },
  swift = {},
  code = {},
}
for _, mode in ipairs { "dark", "light" } do
  apply(mode == "dark" and "xcode_dark" or "xcode_light")
  for _, group in ipairs(swift_groups) do
    result.swift[group] = result.swift[group] or {}
    result.swift[group][mode] = style(group)
  end
  local code_syntax = require "configs.code_syntax"
  code_syntax.build()
  for zed, nvim in pairs(code_names) do
    result.code[zed] = result.code[zed] or {}
    result.code[zed][mode] = style(nvim, code_syntax.ns)
  end
end

local f = assert(io.open(out_path, "w"))
f:write(vim.json.encode(result))
f:close()
vim.cmd "qa!"
