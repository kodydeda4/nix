-- sourcekit-lsp for Zed, with Swift colored exactly like nvim. Zed runs this
-- instead of sourcekit-lsp (settings.json: lsp.sourcekit-lsp.binary):
--   nvim --clean --headless -l ~/.config/zed/xcode/sourcekit.lua
-- It runs the real sourcekit-lsp and passes everything through, except that
-- it answers Zed's semantic token requests itself, with what nvim draws:
--   * tree-sitter: nvim's Swift parser and queries (yours in after/queries
--     too), with their priorities (#set! priority 130)
--   * sourcekit's tokens as nvim's @lsp.type / @lsp.mod / @lsp.typemod groups
--   * configs/lspconfig.lua's extra coloring (operators, generic parameters,
--     globals, the @ / # of attributes, argument labels)
--   * configs/swift_marks.lua's bold MARK:
-- combined like nvim combines highlights: the color of the highest priority
-- (later wins a tie), bold and strikethrough from any of them. Each token's
-- type is that color (xc_keyword...; groups.json, from build.py) and its
-- modifiers bold / strike; Zed's semantic_token_rules map them to the theme.

local uv = vim.uv
local bit = require "bit"
local here = debug.getinfo(1, "S").source:sub(2):match "(.*/)"
local cfg = vim.json.decode(assert(io.open(here .. "groups.json")):read "*a")

local log_path = vim.fn.expand "~/Library/Logs/Zed/sourcekit-xcode.log"
local function log(...)
  local f = io.open(log_path, "a")
  if f then
    f:write(os.date "%Y-%m-%d %H:%M:%S ", table.concat(vim.tbl_map(tostring, { ... }), " "), "\n")
    f:close()
  end
end

-- the legend Zed gets: our types and modifiers
local type_index = {}
for i, name in ipairs(cfg.types) do
  type_index[name] = i - 1
end
-- sourcekit's own legend (it may also send it in its capabilities)
local legend = cfg.sourcekit_legend

-- nvim's Swift parser and highlight queries (query.get concatenates the files)
vim.treesitter.language.add("swift", { path = cfg.parser })
local sources = {}
for _, file in ipairs(cfg.query_files) do
  table.insert(sources, assert(io.open(file)):read "*a")
end
local hl_query = vim.treesitter.query.parse("swift", table.concat(sources, "\n"))

-- byte <-> UTF-16 columns of a line (LSP positions are UTF-16)
local function to_byte(line, col16)
  local ok, b = pcall(vim.str_byteindex, line, "utf-16", col16, false)
  return ok and b or #line
end
local function to_utf16(line, byte)
  local ok, u = pcall(vim.str_utfindex, line, "utf-16", byte, false)
  return ok and u or byte
end

-- configs/lspconfig.lua's argument_labels, on a list of lines instead of a buffer:
-- argument labels of the call whose "(" is right after the callee at
-- (row, col), following the call across lines (up to 80): list of
-- { row, start_col, end_col } (0-based, end exclusive)
local function argument_labels(all_lines, row, col)
  local lines = vim.list_slice(all_lines, row + 1, row + 80)
  if not lines[1] or lines[1]:sub(col + 1, col + 1) ~= "(" then
    return {}
  end
  local labels, depth, expect_label = {}, 0, false
  for li, line in ipairs(lines) do
    local i = li == 1 and (col + 1) or 1
    while i <= #line do
      local ch = line:sub(i, i)
      if ch:match "[%(%[{]" then
        depth = depth + 1
        expect_label = depth == 1
      elseif ch:match "[%)%]}]" then
        depth = depth - 1
        if depth == 0 then
          return labels
        end
      elseif ch == "," and depth == 1 then
        expect_label = true
      elseif ch == '"' then
        local close = line:find('"', i + 1, true)
        if not close then
          break -- multi-line string: give up on the rest of this line
        end
        i, expect_label = close, false
      elseif ch == "/" and line:sub(i + 1, i + 1) == "/" then
        break -- comment
      elseif depth == 1 and expect_label and ch:match "[%a_]" then
        local name_end = line:find("[^%w_]", i) or (#line + 1)
        local colon = line:find("^%s*:", name_end)
        if colon and line:sub(colon + 1, colon + 1) ~= ":" then
          table.insert(labels, { row + li - 1, i - 1, name_end - 1 })
        end
        expect_label = false
      elseif not ch:match "%s" then
        expect_label = false
      end
      i = i + 1
    end
  end
  return labels
end

-- configs/lspconfig.lua's is_local: is `name` (a sourcekit `variable` token at
-- row/col) declared inside an enclosing function / init / closure / accessor?
local local_query = vim.treesitter.query.parse(
  "swift",
  [[
  (parameter name: (simple_identifier) @name)
  (lambda_parameter (simple_identifier) @name)
  (property_declaration (pattern (simple_identifier) @name))
  (if_statement (value_binding_pattern) . (simple_identifier) @name)
  (guard_statement (value_binding_pattern) . (simple_identifier) @name)
  (for_statement (pattern (simple_identifier) @name))
  (switch_pattern (pattern (pattern (simple_identifier) @name)))
]]
)
local scope_types = {
  function_declaration = true,
  init_declaration = true,
  deinit_declaration = true,
  subscript_declaration = true,
  lambda_literal = true,
  computed_getter = true,
  computed_setter = true,
  computed_modify = true,
  computed_property = true,
}
local function is_local(root, text, row, col, name)
  if name:match "^%$" or name == "newValue" or name == "oldValue" then
    return true
  end
  local node = root:named_descendant_for_range(row, col, row, col)
  if not node then
    return false
  end
  local scope = node:parent()
  while scope do
    if scope_types[scope:type()] then
      for _, decl in local_query:iter_captures(scope, text) do
        if vim.treesitter.get_node_text(decl, text) == name then
          return true
        end
      end
    end
    scope = scope:parent()
  end
  return false
end

-- configs/lspconfig.lua's is_generic_parameter: is the `typeParameter` token
-- `name` at row/col a real generic parameter, declared in an enclosing
-- <...> or named in an enclosing where clause (extension Binding where
-- Value == Bool)? sourcekit sends type aliases (IdentifiedArrayOf, ReducerOf)
-- as typeParameter too.
local generic_query = vim.treesitter.query.parse(
  "swift",
  [[
  (type_parameters (type_parameter (type_identifier) @name))
  (type_constraints (type_constraint (_ constrained_type: (identifier (simple_identifier) @name))))
]]
)
local function is_generic_parameter(root, text, row, col, name)
  local scope = root:named_descendant_for_range(row, col, row, col)
  if not scope then
    return true
  end
  while scope do
    for child in scope:iter_children() do
      if child:type() == "type_parameters" or child:type() == "type_constraints" then
        for _, decl in generic_query:iter_captures(child, text) do
          if vim.treesitter.get_node_text(decl, text) == name then
            return true
          end
        end
      end
    end
    scope = scope:parent()
  end
  return false
end

local callee_types = { struct = true, class = true, enum = true, method = true, ["function"] = true, macro = true }

-- the semantic tokens (LSP's relative encoding) for `text`, given sourcekit's
-- tokens for it (`data`, in sourcekit's legend)
local function colorize(text, data)
  local lines = vim.split(text, "\n", { plain = true })
  local spans, seq = {}, 0
  local function add(sr, sc, er, ec, priority, group)
    local style = cfg.groups[group]
    if style then
      seq = seq + 1
      spans[seq] = { sr, sc, er, ec, priority, seq, style }
    end
  end

  -- tree-sitter (nvim's highlighter: priority 100 unless the pattern sets one)
  local root = vim.treesitter.get_string_parser(text, "swift"):parse()[1]:root()
  for id, node, metadata in hl_query:iter_captures(root, text) do
    local priority = tonumber(metadata.priority or (metadata[id] and metadata[id].priority)) or 100
    local sr, sc, er, ec = node:range()
    add(sr, sc, er, ec, priority, "@" .. hl_query.captures[id] .. ".swift")
  end

  -- sourcekit's tokens (nvim's semantic token highlighter: 125 / 126 / 127)
  local tokens = {}
  local row, col16 = 0, 0
  for i = 1, #data - 4, 5 do
    if data[i] > 0 then
      row, col16 = row + data[i], data[i + 1]
    else
      col16 = col16 + data[i + 1]
    end
    local line = lines[row + 1] or ""
    local modifiers = {}
    for b, name in ipairs(legend.tokenModifiers) do
      if bit.band(data[i + 4], bit.lshift(1, b - 1)) ~= 0 then
        modifiers[name] = true
      end
    end
    local token = {
      line = row,
      start_col = to_byte(line, col16),
      end_col = to_byte(line, col16 + data[i + 2]),
      type = legend.tokenTypes[data[i + 3] + 1] or "unknown",
      modifiers = modifiers,
    }
    table.insert(tokens, token)
    add(row, token.start_col, row, token.end_col, 125, "@lsp.type." .. token.type .. ".swift")
    for name in pairs(modifiers) do
      add(row, token.start_col, row, token.end_col, 126, "@lsp.mod." .. name .. ".swift")
      add(row, token.start_col, row, token.end_col, 127, "@lsp.typemod." .. token.type .. "." .. name .. ".swift")
    end
  end

  -- configs/lspconfig.lua's LspTokenUpdate coloring (priority 128)
  for _, token in ipairs(tokens) do
    local line = lines[token.line + 1] or ""
    local word = line:sub(token.start_col + 1, token.end_col)
    local function paint(start_col, end_col, group)
      add(token.line, start_col, token.line, end_col, 128, group)
    end
    if word:match "^[%p]+$" then
      paint(token.start_col, token.end_col, "@operator")
    elseif token.type == "typeParameter" then
      if is_generic_parameter(root, text, token.line, token.start_col, word) then
        paint(token.start_col, token.end_col, "@variable")
      end
    elseif token.type == "variable" and not token.modifiers.defaultLibrary then
      if not is_local(root, text, token.line, token.start_col, word) then
        paint(token.start_col, token.end_col, "@lsp.type.property")
      end
    else
      local group = token.modifiers.defaultLibrary and ("@lsp.typemod." .. token.type .. ".defaultLibrary")
        or ("@lsp.type." .. token.type)
      if token.start_col > 0 and line:sub(token.start_col, token.start_col):match "[@#]" then
        paint(token.start_col - 1, token.start_col, group)
      end
      if callee_types[token.type] then
        for _, r in ipairs(argument_labels(lines, token.line, token.end_col)) do
          add(r[1], r[2], r[1], r[3], 128, group)
        end
      end
    end
  end

  -- configs/swift_marks.lua: `// MARK: title` bold from MARK: on (priority 130)
  for i, line in ipairs(lines) do
    local start = line:find("MARK:", 1, true)
    if start and line:match "^%s*//%s*MARK:" then
      add(i - 1, start - 1, i - 1, #line, 130, "SwiftMark")
    end
  end

  -- combine: lowest priority first, so the highest one's color is left
  table.sort(spans, function(a, b)
    if a[5] ~= b[5] then
      return a[5] < b[5]
    end
    return a[6] < b[6]
  end)
  local cells = {}
  for _, s in ipairs(spans) do
    local style = s[7]
    for r = s[1], s[3] do
      local line = lines[r + 1]
      if not line then
        break
      end
      local from, to = r == s[1] and s[2] or 0, r == s[3] and s[4] or #line
      if to > from then
        local c = cells[r]
        if not c then
          c = { fg = {}, bold = {}, strike = {} }
          cells[r] = c
        end
        for col = from, to - 1 do
          if style.fg then
            c.fg[col] = style.fg
          end
          if style.bold then
            c.bold[col] = true
          end
          if style.strike then
            c.strike[col] = true
          end
        end
      end
    end
  end

  -- one token per run of the same color / bold / strike
  local out, prev_row, prev_col = {}, 0, 0
  for r = 0, #lines - 1 do
    local c = cells[r]
    if c then
      local line = lines[r + 1]
      local col = 0
      while col < #line do
        local fg, bold, strike = c.fg[col], c.bold[col], c.strike[col]
        if fg or bold or strike then
          local stop = col + 1
          while stop < #line and c.fg[stop] == fg and c.bold[stop] == bold and c.strike[stop] == strike do
            stop = stop + 1
          end
          local s16, e16 = to_utf16(line, col), to_utf16(line, stop)
          if e16 > s16 then
            local delta_row = r - prev_row
            table.insert(out, delta_row)
            table.insert(out, delta_row == 0 and (s16 - prev_col) or s16)
            table.insert(out, e16 - s16)
            table.insert(out, type_index[fg or cfg.text_type])
            table.insert(out, (bold and 1 or 0) + (strike and 2 or 0))
            prev_row, prev_col = r, s16
          end
          col = stop
        else
          col = col + 1
        end
      end
    end
  end
  return out
end

-- byte offset in `text` of an LSP position
local function offset(text, pos)
  local start = 1
  for _ = 1, pos.line do
    local nl = text:find("\n", start, true)
    if not nl then
      return #text
    end
    start = nl + 1
  end
  local line_end = text:find("\n", start, true) or (#text + 1)
  return start - 1 + to_byte(text:sub(start, line_end - 1), pos.character)
end

-- JSON-RPC over stdio, both ways

local stdin, stdout = uv.new_pipe(false), uv.new_pipe(false)
stdin:open(0)
stdout:open(1)
local server_in, server_out = uv.new_pipe(false), uv.new_pipe(false)

local function frame(body)
  return "Content-Length: " .. #body .. "\r\n\r\n" .. body
end
local function to_client(body)
  stdout:write(frame(body))
end
local function to_server(body)
  server_in:write(frame(body))
end

-- calls on_message(body) for each message read, in order, outside libuv's
-- callback (where tree-sitter can't run); on_message(nil) at the end
local function reader(on_message)
  local buffer = ""
  return function(err, data)
    if err or not data then
      vim.schedule(function()
        on_message(nil)
      end)
      return
    end
    buffer = buffer .. data
    while true do
      local header_end = buffer:find("\r\n\r\n", 1, true)
      if not header_end then
        return
      end
      local length = tonumber(buffer:sub(1, header_end):match "[Cc]ontent%-[Ll]ength:%s*(%d+)")
      local body_start = header_end + 4
      if not length or #buffer < body_start + length - 1 then
        return
      end
      local body = buffer:sub(body_start, body_start + length - 1)
      buffer = buffer:sub(body_start + length)
      vim.schedule(function()
        on_message(body)
      end)
    end
  end
end

local docs = {} -- uri -> text
local pending = {} -- semantic token request id -> document text then
local initialize_id
local dropped_registrations = {}

local function decode(body)
  local ok, msg = pcall(vim.json.decode, body)
  return ok and type(msg) == "table" and msg or nil
end

local function from_client(body)
  local msg = decode(body)
  if msg then
    local method, params = msg.method, msg.params
    if method == "initialize" then
      initialize_id = msg.id
    elseif method == "textDocument/didOpen" then
      docs[params.textDocument.uri] = params.textDocument.text
    elseif method == "textDocument/didChange" then
      local uri = params.textDocument.uri
      for _, change in ipairs(params.contentChanges or {}) do
        if type(change.range) ~= "table" then
          docs[uri] = change.text
        elseif docs[uri] then
          local text = docs[uri]
          local s, e = offset(text, change.range.start), offset(text, change.range["end"])
          docs[uri] = text:sub(1, s) .. change.text .. text:sub(e + 1)
        end
      end
    elseif method == "textDocument/didClose" then
      docs[params.textDocument.uri] = nil
    elseif method == "textDocument/semanticTokens/full" then
      pending[tostring(msg.id)] = docs[params.textDocument.uri] or ""
    end
  end
  to_server(body)
end

local function from_server(body)
  local msg = decode(body)
  if not msg then
    return to_client(body)
  end

  if msg.method == nil and msg.id ~= nil then
    -- capabilities: our token legend (full documents only, no deltas or
    -- ranges), and whole documents on change so we always have the text
    if initialize_id ~= nil and msg.id == initialize_id and type(msg.result) == "table" then
      initialize_id = nil
      local caps = msg.result.capabilities or {}
      if type(caps.semanticTokensProvider) == "table" and caps.semanticTokensProvider.legend then
        legend = caps.semanticTokensProvider.legend
      end
      caps.semanticTokensProvider = {
        legend = { tokenTypes = cfg.types, tokenModifiers = cfg.modifiers },
        full = true,
        range = false,
      }
      if type(caps.textDocumentSync) == "table" then
        caps.textDocumentSync.change = 1
      else
        caps.textDocumentSync = 1
      end
      msg.result.capabilities = caps
      return to_client(vim.json.encode(msg))
    end

    local text = pending[tostring(msg.id)]
    if text then
      pending[tostring(msg.id)] = nil
      if type(msg.error) == "table" and msg.error.code == -32800 then
        return to_client(body) -- cancelled
      end
      -- without sourcekit's tokens (not ready, or an error), tree-sitter's alone
      local data = type(msg.result) == "table" and type(msg.result.data) == "table" and msg.result.data or {}
      local ok, out = pcall(colorize, text, data)
      if not ok then
        log("colorize failed:", out)
        out = {}
      end
      return to_client(
        '{"jsonrpc":"2.0","id":' .. vim.json.encode(msg.id) .. ',"result":{"data":[' .. table.concat(out, ",") .. "]}}"
      )
    end
  elseif msg.method == "client/registerCapability" and type(msg.params) == "table" then
    -- sourcekit registers its semantic tokens (with its legend) after startup:
    -- keep that to ourselves, Zed already has ours
    local keep = {}
    for _, registration in ipairs(msg.params.registrations or {}) do
      if registration.method == "textDocument/semanticTokens" then
        if type(registration.registerOptions) == "table" and registration.registerOptions.legend then
          legend = registration.registerOptions.legend
        end
        dropped_registrations[registration.id] = true
      else
        table.insert(keep, registration)
      end
    end
    if #keep < #(msg.params.registrations or {}) then
      if #keep == 0 then
        return to_server(vim.json.encode { jsonrpc = "2.0", id = msg.id, result = vim.NIL })
      end
      msg.params.registrations = keep
      return to_client(vim.json.encode(msg))
    end
  elseif msg.method == "client/unregisterCapability" and type(msg.params) == "table" then
    local list = msg.params.unregisterations or {}
    local keep = vim.tbl_filter(function(u)
      return not dropped_registrations[u.id]
    end, list)
    if #keep < #list then
      if #keep == 0 then
        return to_server(vim.json.encode { jsonrpc = "2.0", id = msg.id, result = vim.NIL })
      end
      msg.params.unregisterations = keep
      return to_client(vim.json.encode(msg))
    end
  end
  to_client(body)
end

local function guarded(handler, forward, on_end)
  return function(body)
    if body == nil then
      return on_end and on_end()
    end
    local ok, err = pcall(handler, body)
    if not ok then
      log("error:", err)
      forward(body)
    end
  end
end

local exit_code
local server = os.getenv "SOURCEKIT_LSP" or "/usr/bin/sourcekit-lsp"
local handle = uv.spawn(server, { args = _G.arg, stdio = { server_in, server_out, 2 } }, function(code)
  exit_code = code
end)
if not handle then
  log("could not start", server)
  os.exit(1)
end

-- Zed gone: close sourcekit's input after the last message, so it exits too
stdin:read_start(reader(guarded(from_client, to_server, function()
  server_in:shutdown()
end)))
server_out:read_start(reader(guarded(from_server, to_client)))

while exit_code == nil do
  vim.wait(60000, function()
    return exit_code ~= nil
  end)
end
vim.wait(100) -- let the last writes out
os.exit(exit_code)
