-- Print the rsx! tokens of a Rust file with the capture highlights.scm gives
-- them, the way Zed picks one (the last matching pattern wins), to try a
-- change without rebuilding Zed. Only the rsx patterns: Zed's Rust ones come
-- first in the real thing.
-- nvim --clean --headless --cmd 'set rtp+=~/.local/share/nvim/site' -l try.lua <file.rs> [first line] [last line]
local query_path = vim.fs.joinpath(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)), "highlights.scm")
local path = arg[1]
local first, last = tonumber(arg[2] or 1), tonumber(arg[3] or 1e9)
local src = table.concat(vim.fn.readfile(path), "\n")
local query = vim.treesitter.query.parse("rust", table.concat(vim.fn.readfile(query_path), "\n"))

local outer = vim.treesitter.get_string_parser(src, "rust"):parse()[1]:root()
local macros = vim.treesitter.query.parse("rust", [[
  (macro_invocation macro: [(identifier) @m (scoped_identifier name: (identifier) @m)] (#eq? @m "rsx")) @rsx
]])

-- Only outermost rsx! macros: nested ones are part of the same layer.
local layers = {}
for id, node in macros:iter_captures(outer, src) do
  if macros.captures[id] == "rsx" then
    local p, nested = node:parent(), false
    while p do
      if p:type() == "macro_invocation" then
        for _, l in ipairs(layers) do if l:id() == p:id() then nested = true end end
      end
      p = p:parent()
    end
    if not nested then table.insert(layers, node) end
  end
end

for _, layer in ipairs(layers) do
  local text = vim.treesitter.get_node_text(layer, src)
  local sr, sc = layer:start()
  local root = vim.treesitter.get_string_parser(text, "rust"):parse()[1]:root()
  local captures = {}
  for pattern, match in query:iter_matches(root, text, 0, -1, { all = true }) do
    for id, nodes in pairs(match) do
      local name = query.captures[id]
      if name:sub(1, 1) ~= "_" then
        for _, n in ipairs(nodes) do
          local a, b, c, d = n:range()
          local key = table.concat({ a, b, c, d }, ":")
          if not captures[key] or captures[key].pattern <= pattern then
            captures[key] = { pattern = pattern, name = name }
          end
        end
      end
    end
  end
  local function walk(n)
    if n:child_count() == 0 then
      local a, b, c, d = n:range()
      -- innermost capture covering this leaf, preferring the smallest node
      local name
      local cur = n
      while cur do
        local x1, x2, x3, x4 = cur:range()
        local cap = captures[table.concat({ x1, x2, x3, x4 }, ":")]
        if cap then name = cap.name break end
        cur = cur:parent()
      end
      local line = a + sr + 1
      if line >= first and line <= last then
        io.write(string.format("%d\t%-24s %s\n", line, vim.inspect(vim.treesitter.get_node_text(n, text)), name or "-"))
      end
    end
    for child in n:iter_children() do walk(child) end
  end
  walk(root)
end
