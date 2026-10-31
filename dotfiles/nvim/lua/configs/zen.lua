-- Hyprland's zen mode (Meh+0 / Meh+7, dotfiles/hypr) hides nvim's tab bar and
-- line numbers too (here), and its bottom bar (configs/sidebar_status.lua).
-- Hyprland keeps a flag file while zen mode is on screen; it's watched here,
-- and M.on follows it, with a `User HyprZen` event on every change. (No such
-- file on the Mac: always off there.)
--
-- Space t n shows / hides the line numbers (M.toggle_numbers), in zen mode
-- too; leaving zen mode puts them back how they were before it.

local M = {}
local api = vim.api

local dir = vim.env.XDG_RUNTIME_DIR
local name = "hypr-zen-shown"

local function flag_set()
  return dir ~= nil and vim.uv.fs_stat(dir .. "/" .. name) ~= nil
end

M.on = flag_set()

-- line numbers: on or off in every file window (not the tree, terminals or
-- popups), and in files opened from then on
local numbers = true
local numbers_before_zen = true

local function file_win(win)
  return api.nvim_win_get_config(win).relative == "" and vim.bo[api.nvim_win_get_buf(win)].buftype == ""
end

local function set_numbers(on)
  numbers = on
  for _, win in ipairs(api.nvim_list_wins()) do
    if file_win(win) then
      vim.wo[win].number = on
    end
  end
end

function M.toggle_numbers()
  set_numbers(not numbers)
end

-- a window remembers each file's old setting and brings it back when that
-- file shows again (Ctrl+J / Ctrl+K): keep them all the same
api.nvim_create_autocmd("BufWinEnter", {
  callback = function()
    local win = api.nvim_get_current_win()
    if file_win(win) and vim.wo[win].number ~= numbers then
      vim.wo[win].number = numbers
    end
  end,
})

local applied = false -- zen mode as last applied (M.on can flip faster)
local function apply()
  if M.on == applied then
    return
  end
  applied = M.on
  vim.o.showtabline = M.on and 0 or 2 -- 2: always, like chadrc's lazyload = false
  if M.on then
    numbers_before_zen = numbers
    set_numbers(false)
  else
    set_numbers(numbers_before_zen)
  end
  api.nvim_exec_autocmds("User", { pattern = "HyprZen", modeline = false })
end

if M.on then
  vim.schedule(apply) -- after NvChad turns the tab bar on
end

local watcher = dir and vim.uv.new_fs_event()
if watcher then
  watcher:start(dir, {}, function(err, filename)
    if err or filename ~= name or flag_set() == M.on then
      return
    end
    M.on = not M.on
    vim.schedule(apply)
  end)
end

return M
