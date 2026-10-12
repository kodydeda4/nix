vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

-- check for a real file, not just the folder: a clone that dies halfway
-- (e.g. flaky DNS) leaves an empty folder that would never be retried
if not vim.uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
  vim.fn.delete(lazypath, "rf")
  local repo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
  if vim.v.shell_error ~= 0 then
    vim.fn.delete(lazypath, "rf")
    error("Failed to clone lazy.nvim (relaunch nvim to retry):\n" .. out)
  end
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)
