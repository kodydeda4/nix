-- Undo for the file tree: `u` reverses the last delete, rename / move or
-- create. Deleting moves things to the macOS Trash (so undo can put them back,
-- and Finder's Trash has them too); renames, moves and creates are recorded
-- from nvim-tree's events.

local M = {}

local stack = {} -- undo steps, newest last: { kind = ..., items = { { from, to } } }
local uv = vim.uv

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "File tree" })
end

local function exists(path)
  return uv.fs_lstat(path) ~= nil
end

local function name(path)
  return vim.fn.fnamemodify(path, ":t")
end

local function reload()
  pcall(function() require("nvim-tree.api").tree.reload() end)
end

-- buffers showing `path` (or something inside it, for folders)
local function buffers_under(path)
  local found = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local bname = vim.api.nvim_buf_get_name(buf)
    if bname == path or vim.startswith(bname, path .. "/") then
      table.insert(found, buf)
    end
  end
  return found
end

local function close_buffers(path)
  for _, buf in ipairs(buffers_under(path)) do
    if vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
      pcall(require("nvchad.tabufline").close_buffer, buf)
    end
  end
end

-- buffers follow a rename (so undoing a rename doesn't leave them on the old path)
local function rename_buffers(from, to)
  for _, buf in ipairs(buffers_under(from)) do
    local bname = vim.api.nvim_buf_get_name(buf)
    vim.api.nvim_buf_set_name(buf, to .. bname:sub(#from + 1))
    if vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
      vim.api.nvim_buf_call(buf, function() vim.cmd "silent! edit" end)
    end
  end
end

-- a free name in `dir` for `base` ("x.swift", "x 2.swift", ...), like Finder
local function free_path(dir, base)
  local stem, ext = base:match "^(.-)(%.[^.]*)$"
  if not stem or stem == "" then
    stem, ext = base, ""
  end
  local candidate, n = dir .. "/" .. base, 1
  while exists(candidate) do
    n = n + 1
    candidate = ("%s/%s %d%s"):format(dir, stem, n, ext)
  end
  return candidate
end

-- move `path` to the Trash; returns where it went
local function trash(path)
  local dirs = { vim.fn.expand "~/.Trash", vim.fn.stdpath "state" .. "/tree-trash" }
  for _, dir in ipairs(dirs) do
    vim.fn.mkdir(dir, "p")
    local dest = free_path(dir, name(path))
    if uv.fs_rename(path, dest) then
      return dest
    end
  end
end

local function push(kind, items)
  if #items > 0 then
    table.insert(stack, { kind = kind, items = items })
  end
end

--- Delete (move to the Trash) after a red confirmation popup; `paths` is a list
function M.delete(paths)
  if #paths == 0 then
    return
  end
  -- worded like nvim-tree's prompts so the popup styling (red, "Delete ... Y/N") applies
  local prompt = #paths == 1 and ("Remove " .. name(paths[1]) .. "? y/N: ") or "Remove bookmarked ? y/N: "
  vim.ui.input({ prompt = prompt }, function(answer)
    if not answer or answer:sub(1, 1):lower() ~= "y" then
      return
    end
    local items = {}
    for _, path in ipairs(paths) do
      local dest = trash(path)
      if dest then
        close_buffers(path)
        table.insert(items, { from = path, to = dest })
      else
        notify("Couldn't move " .. name(path) .. " to the Trash", vim.log.levels.ERROR)
      end
    end
    push("delete", items)
    pcall(function() require("nvim-tree.api").marks.clear() end)
    reload()
  end)
end

-- renames / moves / creates from nvim-tree; the ones from one action (e.g.
-- `a/b/c.swift` creates two folders and a file) become a single undo step
local pending = {}
local function record(kind, item)
  if M.undoing then
    return
  end
  if not pending[kind] then
    pending[kind] = {}
    vim.schedule(function()
      local items = pending[kind]
      pending[kind] = nil
      push(kind, kind == "create" and M.created(items) or items)
    end)
  end
  table.insert(pending[kind], item)
end

-- nvim-tree reports each folder it makes for `a/b/c.swift` with the full path
-- (not the folder's own), once per new folder, deepest last. So n folder events
-- mean the n innermost folders on that path are new; undoing trashes the
-- outermost of them, which takes the rest (and the file) with it.
function M.created(items)
  local file, folders, path = nil, 0, nil
  for _, item in ipairs(items) do
    if item.folder then
      folders = folders + 1
      path = item.to:gsub("/+$", "")
    else
      file = item.to
    end
  end
  if folders == 0 then
    return items
  end
  local top = file and vim.fn.fnamemodify(file, ":h") or path
  for _ = 2, folders do
    top = vim.fn.fnamemodify(top, ":h")
  end
  return { { to = top } }
end

function M.setup()
  if M.ready then
    return
  end
  M.ready = true
  local api = require "nvim-tree.api"
  local Event = api.events.Event
  api.events.subscribe(Event.NodeRenamed, function(data)
    record("rename", { from = data.old_name, to = data.new_name })
  end)
  api.events.subscribe(Event.FileCreated, function(data)
    record("create", { to = data.fname })
  end)
  api.events.subscribe(Event.FolderCreated, function(data)
    record("create", { to = data.folder_name, folder = true })
  end)
end

local labels = { delete = "delete", rename = "rename / move", create = "create" }

function M.undo()
  local step = table.remove(stack)
  if not step then
    notify "Nothing to undo"
    return
  end
  M.undoing = true
  local failed = {}
  -- newest first, so nested items (a folder and the file inside it) unwind in order
  for i = #step.items, 1, -1 do
    local item = step.items[i]
    if step.kind == "delete" or step.kind == "rename" then
      -- put back: from the Trash, or to the old name
      if exists(item.from) then
        table.insert(failed, name(item.from) .. " (something's already there)")
      elseif not uv.fs_rename(item.to, item.from) then
        table.insert(failed, name(item.from))
      elseif step.kind == "rename" then
        rename_buffers(item.to, item.from)
      end
    elseif step.kind == "create" then
      -- to the Trash rather than deleted, in case it has new content by now
      if exists(item.to) then
        close_buffers(item.to)
        if not trash(item.to) then
          table.insert(failed, name(item.to))
        end
      end
    end
  end
  M.undoing = false
  reload()
  local what = #step.items == 1 and name(step.items[1].from or step.items[1].to) or (#step.items .. " items")
  if #failed > 0 then
    notify("Couldn't undo " .. labels[step.kind] .. " of " .. table.concat(failed, ", "), vim.log.levels.WARN)
  else
    notify("Undid " .. labels[step.kind] .. ": " .. what)
  end
end

return M
