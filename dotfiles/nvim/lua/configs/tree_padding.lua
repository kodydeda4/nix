-- Right-hand padding in the file tree, matching the space on the left: the last
-- PAD columns of every row are drawn blank over the glass, so long names and
-- the selected row's highlight stop short of the divider.

local PAD = 1 -- same as the 1-column margin on the left (configs/glass.lua)
local ns = vim.api.nvim_create_namespace "tree_right_padding"
local blank = { { string.rep(" ", PAD), "NvimTreeNormal" } }
local col = {}

vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, win, buf)
    if vim.bo[buf].filetype ~= "NvimTree" then
      return false
    end
    local info = vim.fn.getwininfo(win)[1]
    col[win] = info and (info.width - info.textoff - PAD) or nil
    return col[win] ~= nil and col[win] > 0
  end,
  on_line = function(_, win, buf, row)
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
      virt_text = blank,
      virt_text_win_col = col[win],
      hl_mode = "replace", -- covers the selected row's background too
      ephemeral = true,
    })
  end,
})

