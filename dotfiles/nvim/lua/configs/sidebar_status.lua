-- The bottom bar:
--   under the file tree: the repo name, then the git branch
--   under the editor, on its solid background: the vim mode, plus the
--     language server's progress while it's busy ("Indexing…"), on the left;
--     error / warning / hint / info counts on the right edge (click
--     one to hide / show that severity in the editor)
-- Every item shows even when it's zero or idle, so the layout stays put.
-- With the tree closed, only the editor part shows, across the whole width.
-- With the cursor in the tree, it describes the last file window you were in.

local utils = require "nvchad.stl.utils"
local api = vim.api

local function tree_win()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].filetype == "NvimTree" then
      return win
    end
  end
end

-- the current folder's repo and branch, for when the buffer has none of its
-- own (no file open yet): read in the background, refreshed on the events below
local cwd_branch, cwd_repo = "", ""
local function redraw()
  vim.schedule(function()
    vim.cmd.redrawstatus()
  end)
end
local function refresh()
  local cwd = vim.uv.cwd()
  pcall(vim.system, { "git", "branch", "--show-current" }, { text = true, cwd = cwd }, function(out)
    local branch = out.code == 0 and vim.trim(out.stdout or "") or ""
    if branch ~= cwd_branch then
      cwd_branch = branch
      redraw()
    end
  end)
  pcall(vim.system, { "git", "rev-parse", "--show-toplevel" }, { text = true, cwd = cwd }, function(out)
    local root = out.code == 0 and vim.trim(out.stdout or "") or ""
    local repo = root:match "([^/]+)$" or ""
    if repo ~= cwd_repo then
      cwd_repo = repo
      redraw()
    end
  end)
end
refresh()
api.nvim_create_autocmd({ "VimEnter", "DirChanged", "FocusGained", "BufWritePost" }, {
  callback = refresh,
})

local function git_status()
  return vim.b[utils.stbufnr()].gitsigns_status_dict or {}
end

-- "<repo icon> repo": the open file's repo (gitsigns knows it), or the folder's
local function repo()
  local root = git_status().root
  local name = root and root:match "([^/]+)/*$" or cwd_repo
  return "%#SidebarBranch# " .. (name ~= "" and name or "no repo")
end

-- "<branch icon> branch"
local function branch()
  local status = git_status()
  local head = status.head and status.head ~= "" and status.head or cwd_branch
  if head == "" then
    return "%#SidebarBranch# no branch "
  end
  return "%#SidebarBranch# " .. head .. " "
end

-- Click a count (left or right) to hide / show that severity in the editor (underline,
-- signs, virtual text); a hidden one keeps counting but is crossed out.
local hidden = {}
local shown_in = { "underline", "signs", "virtual_text", "virtual_lines" }
function _G.SidebarDiagnosticClick(severity, _, button)
  if button ~= "l" and button ~= "r" then
    return
  end
  hidden[severity] = not hidden[severity] or nil
  local visible = {}
  for _, sev in ipairs { 1, 2, 3, 4 } do
    if not hidden[sev] then
      visible[#visible + 1] = sev
    end
  end
  local config = vim.diagnostic.config() or {}
  local update = {}
  for _, key in ipairs(shown_in) do
    local value = config[key]
    if value then
      value = type(value) == "table" and vim.deepcopy(value) or {}
      value.severity = #visible < 4 and visible or nil
      update[key] = value
    end
  end
  vim.diagnostic.config(update)
  redraw()
end

-- "✖ 0  ⚠ 0  󰛩 0  󰋼 0", each gray at zero, crossed out while hidden
local function diagnostics()
  local buf = utils.stbufnr()
  local function count(severity, hl, icon)
    local n = rawget(vim, "lsp") and #vim.diagnostic.get(buf, { severity = severity }) or 0
    -- gray while zero, the severity's color once there's something to see
    local group = hidden[severity] and "Off_Comment" or (n > 0 and hl or "Comment")
    return "%" .. severity .. "@v:lua.SidebarDiagnosticClick@%#" .. group .. "#" .. icon .. n .. "%X%#Comment# "
  end
  local s = vim.diagnostic.severity
  return count(s.ERROR, "St_lspError", " ")
    .. count(s.WARN, "St_lspWarning", " ")
    .. count(s.HINT, "St_lspHints", "󰛩 ")
    .. count(s.INFO, "St_lspInfo", "󰋼 ")
end

-- the vim mode (NORMAL, INSERT...), NvChad's colors; then the language
-- server's progress while it's busy ("Indexing…")
local function mode_and_progress()
  local m = utils.modes[api.nvim_get_mode().mode] or { "NORMAL", "Normal" }
  local mode = "%#St_" .. m[2] .. "Mode#  " .. m[1]
  local progress = utils.state.lsp_msg ~= "" and ("%#St_LspMsg#   " .. utils.state.lsp_msg) or ""
  return mode .. progress
end

-- Items under the editor need the editor's solid background: "EdBar_<group>"
-- is <group>'s text color on it. (Not "<group>_Ed": options.lua strips the
-- background from every St_* group, which made these see-through.) Updated
-- whenever <group> or the editor color changes, e.g. after a light / dark switch.
local made = {}
local function to_editor(str)
  return (str:gsub("%%#([%w_]+)#", function(group)
    local name = "EdBar_" .. group
    -- "Off_<group>": <group> crossed out
    local base = group:match "^Off_(.+)" or group
    local strike = base ~= group or nil
    local hl = api.nvim_get_hl(0, { name = base, link = false })
    local bg = api.nvim_get_hl(0, { name = "XcodeEditor", link = false }).bg
    local key = tostring(hl.fg) .. ":" .. tostring(bg) .. ":" .. tostring(hl.bold)
    if made[name] ~= key then
      api.nvim_set_hl(0, name, { fg = hl.fg, bg = bg, bold = hl.bold, strikethrough = strike })
      made[name] = key
    end
    return "%#" .. name .. "#"
  end))
end
api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    made = {}
  end,
})
api.nvim_create_autocmd("User", {
  pattern = "NvThemeReload",
  callback = function()
    made = {}
  end,
})

local function width(str)
  return api.nvim_eval_statusline(str, {}).width
end

-- With the ⌘⇧Y terminal open below the editor, the bar moves up between them,
-- like Xcode's debug area: per-window status lines with none on the last row
-- (laststatus=0) means only the window above the terminal gets one. Back to
-- the single bottom bar (laststatus=3) once the terminal closes.
local function term_below_editor()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if vim.bo[api.nvim_win_get_buf(win)].buftype == "terminal" and api.nvim_win_get_config(win).relative == "" then
      local has_above = api.nvim_win_call(win, function()
        return vim.fn.winnr "k" ~= vim.fn.winnr()
      end)
      if has_above then
        return true
      end
    end
  end
  return false
end
api.nvim_create_autocmd({ "WinNew", "WinClosed", "BufWinEnter", "TermOpen", "TabEnter" }, {
  callback = function()
    vim.schedule(function()
      local want = term_below_editor() and 0 or 3
      if vim.o.laststatus ~= want then
        vim.o.laststatus = want
      end
    end)
  end,
})

-- the bar above the terminal: the tree-closed layout, as wide as its window
local function above_terminal()
  local win = vim.g.statusline_winid or api.nvim_get_current_win()
  local left = to_editor("%#XcodeEditor#" .. mode_and_progress())
  local right = to_editor(branch() .. "%#XcodeEditor#  " .. diagnostics())
  local gap = math.max(api.nvim_win_get_width(win) - width(left .. right), 1)
  return left .. to_editor "%#XcodeEditor#" .. string.rep(" ", gap) .. right
end

return function()
  if vim.o.laststatus ~= 3 then
    return above_terminal()
  end

  -- in the tree: describe the previous window (the file you came from)
  if vim.bo[api.nvim_get_current_buf()].filetype == "NvimTree" then
    local prev = vim.fn.win_getid(vim.fn.winnr "#")
    if prev ~= 0 then
      vim.g.statusline_winid = prev
    end
  end

  local tree = tree_win()
  local sidebar_width = tree and api.nvim_win_get_width(tree) or 0

  -- under the tree: the repo, then the branch right after it
  local sidebar = ""
  if tree then
    -- lined up with the tree's text, past its sign column
    local info = vim.fn.getwininfo(tree)[1]
    local indent = string.rep(" ", info and info.textoff or 0)
    local repo_and_branch = repo() .. "  " .. branch():gsub("^(%%#SidebarBranch#) ", "%1")
    if width(indent .. repo_and_branch) > sidebar_width then
      repo_and_branch = branch():gsub("^(%%#SidebarBranch#) ", "%1") -- too narrow: the branch wins
    end
    local left, right = "%#StatusLine#" .. indent .. repo_and_branch, ""
    local gap = math.max(sidebar_width - width(left .. right), 0)
    sidebar = left .. "%#StatusLine#" .. string.rep(" ", gap) .. right
  end

  -- under the editor: vim mode (and LSP progress) left, diagnostics on the right edge
  local room = vim.o.columns - sidebar_width
  local left = to_editor("%#XcodeEditor#" .. mode_and_progress())
  local right = to_editor(diagnostics())
  if not tree then
    -- tree closed: the branch moves here, next to the diagnostics
    right = to_editor(branch() .. "%#XcodeEditor#  ") .. right
  end
  local gap = math.max(room - width(left .. right), 1)
  return sidebar .. left .. to_editor "%#XcodeEditor#" .. string.rep(" ", gap) .. right
end
