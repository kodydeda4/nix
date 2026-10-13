-- Swift snippets for nvim, read from espanso's match/_swift-developer.yml (the
-- file Xcode and Zed get through espanso), so there's one list to edit.
-- They expand as you type the trigger, like espanso, but only in insert mode
-- in Swift files (espanso itself can't tell insert from normal mode in a
-- terminal, where its keystrokes would run as vim commands).
-- After editing the YAML, restart nvim to reload them.
local ls = require "luasnip"

local file = vim.fn.resolve(vim.fn.stdpath "config") .. "/../espanso/match/_swift-developer.yml"

-- the double-quoted YAML escapes the file uses
local escapes = { n = "\n", t = "\t", ['"'] = '"', ["\\"] = "\\" }
local function unquote(s)
  return (s:gsub("\\(.)", function(c)
    return escapes[c] or ("\\" .. c)
  end))
end

local f = io.open(file)
if not f then
  return
end

local snippets, trigger = {}, nil
for line in f:lines() do
  local t = line:match '^%s*%- trigger: "(.*)"%s*$'
  local r = line:match '^%s*replace: "(.*)"%s*$'
  if t then
    trigger = unquote(t)
  elseif r and trigger then
    local text = vim.split(unquote(r), "\n", { plain = true })
    table.insert(
      snippets,
      ls.snippet({ trig = trigger, wordTrig = false, snippetType = "autosnippet" }, ls.text_node(text))
    )
    trigger = nil
  end
end
f:close()

ls.add_snippets("swift", snippets, { key = "espanso-swift" })

-- Expand them ourselves rather than with LuaSnip's enable_autosnippets: that
-- checks in the middle of autopairs typing "(" -> "()", sees "clock()" and
-- expands too early. Checking once the keystroke is done fires on the ")" you
-- type over (a cursor move, hence CursorMovedI), like espanso.
vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
  group = vim.api.nvim_create_augroup("EspansoSwiftSnippets", { clear = true }),
  callback = function(args)
    if vim.bo[args.buf].filetype ~= "swift" then
      return
    end
    vim.schedule(function()
      if vim.api.nvim_get_mode().mode == "i" and vim.api.nvim_get_current_buf() == args.buf then
        ls.expand_auto()
      end
    end)
  end,
})
