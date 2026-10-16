-- Folded code shows its first line in its usual colors, then a "⋯" pill and how
-- many lines are hidden (like Xcode's ··· bubble). Used as 'foldtext'
-- (options.lua): nvim doesn't draw end-of-line markers on folded lines, so the
-- line's colors are rebuilt here from treesitter and the semantic tokens.

local M = {}

local function colors()
  local comment = vim.api.nvim_get_hl(0, { name = "@comment", link = false }).fg
  local cursorline = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false }).bg
  vim.api.nvim_set_hl(0, "FoldMarker", { fg = comment, bg = cursorline, bold = true })
  vim.api.nvim_set_hl(0, "FoldMarkerCount", { fg = comment, italic = true })
end
colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

-- highlight group per byte of `row` (0-based), highest priority wins
local function line_groups(buf, row, line)
  local groups, prio = {}, {}
  local function paint(from, to, group, priority)
    for col = from, math.min(to, #line) - 1 do
      if not prio[col] or priority >= prio[col] then
        groups[col], prio[col] = group, priority
      end
    end
  end

  local ok, parser = pcall(vim.treesitter.get_parser, buf)
  if ok and parser then
    parser:for_each_tree(function(tree, ltree)
      local query = vim.treesitter.query.get(ltree:lang(), "highlights")
      if not query then
        return
      end
      for id, node, metadata in query:iter_captures(tree:root(), buf, row, row + 1) do
        local name = query.captures[id]
        if name:sub(1, 1) ~= "_" and name ~= "spell" and name ~= "nospell" then
          local srow, scol, erow, ecol = node:range()
          local from = srow < row and 0 or scol
          local to = erow > row and #line or ecol
          local priority = tonumber(metadata.priority or (metadata[id] and metadata[id].priority)) or 100
          paint(from, to, "@" .. name .. "." .. ltree:lang(), priority)
        end
      end
    end)
  end

  -- semantic tokens and the extra coloring from lspconfig.lua (extmarks)
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, { row, 0 }, { row, -1 }, { details = true, type = "highlight" })) do
    local d = mark[4]
    if d.hl_group and (d.end_row or row) == row then
      paint(mark[3], d.end_col or #line, d.hl_group, d.priority or 4096)
    end
  end
  return groups
end

function M.text()
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.v.foldstart - 1
  local line = vim.fn.getline(vim.v.foldstart)
  local groups = line_groups(buf, row, line)

  local chunks, tab = {}, string.rep(" ", vim.bo[buf].tabstop)
  local col = 0
  while col < #line do
    local group, stop = groups[col], col + 1
    while stop < #line and groups[stop] == group do
      stop = stop + 1
    end
    table.insert(chunks, { (line:sub(col + 1, stop):gsub("\t", tab)), group or "Normal" })
    col = stop
  end
  table.insert(chunks, { " " })
  table.insert(chunks, { " ⋯ ", "FoldMarker" })
  table.insert(chunks, { (" %d lines"):format(vim.v.foldend - vim.v.foldstart), "FoldMarkerCount" })
  return chunks
end

_G.XcodeFoldText = M.text

return M
