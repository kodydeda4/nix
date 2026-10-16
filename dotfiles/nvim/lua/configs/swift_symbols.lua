-- Symbol search like Xcode's Open Quickly: types, functions, properties and
-- enum cases from sourcekit-lsp's index. Your project's symbols come first,
-- then the packages' (each shown with its package name); left out are the
-- names macros generate (#Preview's mangled `$s...` structs, @ObservableState's
-- `_store` / `init:store` members) and build-plugin generated code.

local M = {}

local function junk(name)
  return name:sub(1, 1) == "$" -- mangled (#Preview registries...)
    or name:sub(1, 1) == "_" -- macro backing storage (_toastManager)
    or name:match "^[%w_]+:[%w_]" ~= nil -- macro accessors (init:toastManager)
end

-- 0 = your project, 1 = a package checkout, nil = leave out
local function group(path)
  if path:find("/DerivedData/", 1, true) then
    if path:find("/SourcePackages/checkouts/", 1, true) then
      return 1
    end
    return nil -- generated (build plugins, macro expansions...)
  end
  return 0
end

-- "File.swift", or "package › File.swift" for package code
local function show_path(_, path)
  local package = path:match "/SourcePackages/checkouts/([^/]+)/"
  local file = vim.fn.fnamemodify(path, ":t")
  return package and (package .. " › " .. file) or file
end

local function symbol_name(item)
  return (item.text or ""):match "^%[.-%]%s*(.*)$" or item.text or ""
end

local layout = {
  fname_width = 45,
  symbol_width = 55,
  symbol_type_width = 12,
  path_display = show_path,
}

-- The sourcekit for the whole app: the one rooted at the folder with
-- buildServer.json (packages get their own sourcekit, which only knows that
-- package). Started here when no Swift file is open yet, e.g. right after
-- launching nvim on the project.
local function project_client()
  local cwd = vim.fn.getcwd()
  local root = vim.fs.root(cwd, "buildServer.json") or vim.fs.root(cwd, "Package.swift") or cwd
  for _, client in ipairs(vim.lsp.get_clients { name = "sourcekit" }) do
    if client.root_dir == root then
      return client
    end
  end
  -- NvChad loads nvim-lspconfig (and configs/lspconfig.lua) only once a file opens
  require("lazy").load { plugins = { "nvim-lspconfig" } }
  if not vim.lsp.config.sourcekit then
    return nil
  end
  local config = vim.tbl_extend("force", vim.lsp.config.sourcekit, { root_dir = root })
  local id = vim.lsp.start(config, { attach = false })
  if id then
    vim.notify("Starting sourcekit; results fill in as it loads the index", vim.log.levels.INFO, { title = "Open Quickly" })
  end
  return id and vim.lsp.get_client_by_id(id)
end

--- the whole project (⌘⇧O / Space f s); results update as you type
function M.project()
  local bufnr = vim.api.nvim_get_current_buf()
  local client = project_client()
  if not client then
    vim.notify("No sourcekit for this folder", vim.log.levels.WARN, { title = "Open Quickly" })
    return
  end
  local opts = vim.tbl_extend("force", layout, { bufnr = bufnr })
  local conf = require("telescope.config").values
  local channel = require("plenary.async.control").channel
  local cancel = function() end

  local function request(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    local ok, id = client:request("workspace/symbol", { query = prompt }, function(err, result)
      tx(err and {} or (result or {}))
    end)
    cancel = function()
      if ok then
        client:cancel_request(id)
      end
    end
    local items = {}
    for _, item in ipairs(vim.lsp.util.symbols_to_items(rx(), bufnr, client.offset_encoding)) do
      local g = group(item.filename or "")
      if g and not junk(symbol_name(item)) then
        item.xcode_group = g
        table.insert(items, item)
      end
    end
    return items
  end

  local make = require("telescope.make_entry").gen_from_lsp_symbols(opts)
  local function entry_maker(item)
    local entry = make(item)
    if entry then
      entry.xcode_group = item.xcode_group
    end
    return entry
  end

  -- sourcekit already ranks results well (exact names first); keep its order,
  -- just with your project's symbols above the packages'
  local fuzzy = conf.generic_sorter(opts)
  local sorter = require("telescope.sorters").Sorter:new {
    scoring_function = function(_, _, _, entry)
      return (entry.xcode_group or 0) * 100000 + (entry.index or 0)
    end,
    highlighter = fuzzy.highlighter, -- still highlight the matched letters
  }

  require("telescope.pickers")
    .new(opts, {
      prompt_title = "Open Quickly (symbols)",
      finder = require("telescope.finders").new_dynamic { fn = request, entry_maker = entry_maker },
      previewer = conf.qflist_previewer(opts),
      sorter = sorter,
    })
    :find()
end

--- just this file (Space f d), like Xcode's jump bar
function M.file()
  local opts = vim.tbl_extend("force", layout, { prompt_title = "Symbols in this file", path_display = { "hidden" } })
  local make = require("telescope.make_entry").gen_from_lsp_symbols(opts)
  opts.entry_maker = function(item)
    if junk(symbol_name(item)) then
      return nil
    end
    return make(item)
  end
  require("telescope.builtin").lsp_document_symbols(opts)
end

return M
