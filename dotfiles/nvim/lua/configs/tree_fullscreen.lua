-- The file tree full screen, in place of the code instead of beside it: ⌘0 /
-- Space e switch the editor's window between the file and the tree, and Enter
-- in the tree opens a file right there (plugins/init.lua). Still glass, like
-- the sidebar it used to be (configs/glass.lua).

local M = {}

local function in_tree()
  return vim.bo.filetype == "NvimTree"
end

-- back to the file you came from (or an empty editor)
function M.close()
  local alt = vim.fn.bufnr "#"
  if alt > 0 and vim.bo[alt].buflisted then
    vim.cmd.buffer(alt)
  else
    vim.cmd.enew()
  end
end

-- the tree's glass and margin (configs/glass.lua) go on as it opens, before
-- it's drawn: done any later, its text shifts over by the margin
local function styled(open)
  open()
  if in_tree() then
    require("configs.glass").solid(vim.api.nvim_get_current_win())
  end
end

function M.open()
  styled(function()
    require("nvim-tree.api").tree.open { current_window = true }
  end)
end

-- the tree, with the current file (if any) selected in it
function M.reveal()
  if in_tree() then
    return
  end
  if vim.api.nvim_buf_get_name(0) == "" then
    return M.open()
  end
  styled(function()
    require("nvim-tree.api").tree.find_file { open = true, focus = true, current_window = true }
  end)
end

-- (opening it selects the file you're in, like ⌘⇧J)
function M.toggle()
  if in_tree() then
    M.close()
  else
    M.reveal()
  end
end

return M
