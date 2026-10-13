-- Color the innermost { }, [ ], < > or ( ) around the cursor (Xcode-style scope
-- indicator).
-- Uses the treesitter syntax tree, so it works in any language with a parser.

local ns = vim.api.nvim_create_namespace "scope_braces"

local function define_color()
  -- a darker gold on light themes so it stays readable on white
  local gold = vim.o.background == "light" and "#b8860b" or "#ffd60a"
  vim.api.nvim_set_hl(0, "ScopeBrace", { fg = gold, bold = true })
  vim.api.nvim_set_hl(0, "ScopeCursor", { fg = vim.o.background == "light" and "#ffffff" or "#000000", bg = gold })
  -- light themes: a system-blue cursor, like the text cursor in Xcode / macOS
  vim.api.nvim_set_hl(0, "LightCursor", { fg = "#ffffff", bg = "#007aff" })
end
define_color()

local function update(buf)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf })
  if not ok or not node then
    return
  end
  local pairs_ = { ["{"] = "}", ["["] = "]", ["<"] = ">", ["("] = ")" }
  while node do
    -- a node whose own (unnamed) children open and close with the same pair
    local open, close
    for child in node:iter_children() do
      if not child:named() then
        local kind = child:type()
        if not open and pairs_[kind] then
          open = child
        elseif open and kind == pairs_[open:type()] then
          close = child
        end
      end
    end
    if open and close then
      for _, brace in ipairs { open, close } do
        local row, col = brace:range()
        vim.api.nvim_buf_set_extmark(buf, ns, row, col, { end_col = col + 1, hl_group = "ScopeBrace", priority = 200 })
      end
      return
    end
    node = node:parent()
  end
end

-- The bracket under the cursor is drawn by the terminal in the cursor's own
-- colors, so on a bracket the cursor itself turns gold. Elsewhere the cursor is
-- the terminal's own, or blue in light themes.
local default_guicursor = vim.o.guicursor
local function colored(group)
  return ("n-v-c-sm:block-%s,i-ci-ve:ver25-%s,r-cr-o:hor20-%s,t:block-blinkon500-blinkoff500-TermCursor"):format(group, group, group)
end
local on_bracket = false
local function set_cursor()
  if on_bracket then
    vim.o.guicursor = colored "ScopeCursor"
  elseif vim.o.background == "light" then
    vim.o.guicursor = colored "LightCursor"
  else
    vim.o.guicursor = default_guicursor
  end
end
local function update_cursor()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local char = vim.api.nvim_get_current_line():sub(col + 1, col + 1)
  local now = char:match "[%{%}%[%]%(%)<>]" ~= nil
  if now ~= on_bracket then
    on_bracket = now
    set_cursor()
  end
end
set_cursor()

local group = vim.api.nvim_create_augroup("ScopeBraces", { clear = true })
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
  group = group,
  callback = function(args)
    update(args.buf)
    update_cursor()
  end,
})
vim.api.nvim_create_autocmd("BufLeave", {
  group = group,
  callback = function(args)
    vim.api.nvim_buf_clear_namespace(args.buf, ns, 0, -1)
  end,
})
vim.api.nvim_create_autocmd("ColorScheme", {
  group = group,
  callback = function()
    define_color()
    set_cursor()
  end,
})
