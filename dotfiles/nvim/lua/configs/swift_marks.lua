-- `// MARK: - Title` like Xcode: the title in bold, and with the `-`, a thin
-- line across the editor above it (drawn as an underline of the line above).

local ns = vim.api.nvim_create_namespace "swift_marks"

local function define_colors()
  local comment = vim.api.nvim_get_hl(0, { name = "@comment", link = false })
  local sep = vim.api.nvim_get_hl(0, { name = "WinSeparator", link = false })
  vim.api.nvim_set_hl(0, "SwiftMark", { fg = comment.fg, bold = true })
  vim.api.nvim_set_hl(0, "SwiftMarkLine", { underline = true, sp = sep.fg })
end
define_colors()

local function update(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  define_colors() -- the theme's comment color may load after this file
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local start = line:find "MARK:"
    if start and line:match "^%s*//%s*MARK:" then
      vim.api.nvim_buf_set_extmark(buf, ns, row - 1, start - 1, {
        end_col = #line,
        hl_group = "SwiftMark",
        priority = 130, -- over the comment color
      })
      if line:match "MARK:%s*%-" and row > 1 then
        vim.api.nvim_buf_set_extmark(buf, ns, row - 2, 0, { line_hl_group = "SwiftMarkLine" })
      end
    end
  end
end

local group = vim.api.nvim_create_augroup("SwiftMarks", { clear = true })
local pending = {}
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
  group = group,
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "swift" or pending[args.buf] then
      return
    end
    pending[args.buf] = true
    vim.defer_fn(function()
      pending[args.buf] = nil
      update(args.buf)
    end, 100)
  end,
})
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_colors })

return { update = update }
