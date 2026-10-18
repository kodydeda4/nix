require("nvchad.configs.lspconfig").defaults()

-- sourcekit: Swift (Apple's sourcekit-lsp; with buildServer.json from
-- xcode-build-server it understands Xcode projects too).
-- Semantic tokens tell your code apart from Apple's (the `defaultLibrary`
-- modifier), which the xcode_dark theme colors like Xcode. sourcekit only
-- offers them to editors that accept capabilities registered after startup.
vim.lsp.config("sourcekit", {
  capabilities = {
    textDocument = { semanticTokens = { dynamicRegistration = true } },
  },
  -- a package's Package.swift gets its own sourcekit rooted at the package, so
  -- it's analyzed as a SwiftPM manifest (the Xcode build settings in
  -- buildServer.json don't cover manifests); everything else as before
  root_dir = function(bufnr, on_dir)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if vim.fs.basename(name) == "Package.swift" then
      return on_dir(vim.fs.dirname(name))
    end
    -- nvim-lspconfig's default for sourcekit
    local util = require "lspconfig.util"
    on_dir(
      util.root_pattern("buildServer.json", ".bsp")(name)
        or util.root_pattern("*.xcodeproj", "*.xcworkspace")(name)
        or util.root_pattern("compile_commands.json", "Package.swift")(name)
        or vim.fs.dirname(vim.fs.find(".git", { path = name, upward = true })[1])
    )
  end,
})

-- nvim 0.12 accepts that late registration but then looks for the token legend
-- in the startup capabilities, so copy it there.
local register_capability = vim.lsp.handlers["client/registerCapability"]
vim.lsp.handlers["client/registerCapability"] = function(err, params, ctx)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  for _, registration in ipairs(params.registrations or {}) do
    if client and registration.method == "textDocument/semanticTokens" then
      client.server_capabilities.semanticTokensProvider = registration.registerOptions
    end
  end
  return register_capability(err, params, ctx)
end

-- Extra Xcode-style coloring on top of sourcekit's tokens (xcode_dark theme):
--  * operators (>, !, ??) come as Apple methods: show them plain
--  * the "@" / "#" of an attribute or macro takes its name's color (@Shared, #Preview)
--  * argument labels take the callee's color (CGSize(width:), LabelState(title:))
--  * generic parameters (<Content: View>, Binding's Value) stay plain
--  * global variables (isTesting) take the member color; locals stay plain

-- argument labels of the call whose "(" is right after the callee at
-- (row, col), following the call across lines (up to 80): list of
-- { row, start_col, end_col } (0-based, end exclusive)
local function argument_labels(buf, row, col)
  local lines = vim.api.nvim_buf_get_lines(buf, row, row + 80, false)
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

-- Is `name` (a sourcekit `variable` token at row/col) declared locally, i.e.
-- inside an enclosing function / init / closure / accessor? sourcekit sends
-- globals and locals alike as `variable`; Xcode shows only locals plain.
local local_query
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
local function is_local(buf, row, col, name)
  if name:match "^%$" or name == "newValue" or name == "oldValue" then
    return true
  end
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col }, lang = "swift" })
  if not ok or not node then
    return false
  end
  local_query = local_query
    or vim.treesitter.query.parse(
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
  local scope = node:parent()
  while scope do
    if scope_types[scope:type()] then
      for _, decl in local_query:iter_captures(scope, buf) do
        if vim.treesitter.get_node_text(decl, buf) == name then
          return true
        end
      end
    end
    scope = scope:parent()
  end
  return false
end

local label_ns = vim.api.nvim_create_namespace "xcode_argument_labels"

-- nvim 0.12 bug: on the first line of a closed fold only the first token gets
-- colored (the rest of that line is treated as hidden), so `struct State:
-- Sendable, Equatable` folded showed Equatable white. When that first token is
-- drawn, draw the rest of the line's tokens the way nvim would.
local priority = vim.hl.priorities.semantic_tokens
vim.api.nvim_create_autocmd("LspTokenUpdate", {
  callback = function(args)
    local token, buf, client_id = args.data.token, args.buf, args.data.client_id
    if vim.fn.foldclosed(token.line + 1) ~= token.line + 1 then
      return
    end
    local st = vim.lsp.semantic_tokens
    local ft = vim.bo[buf].filetype
    local line = vim.api.nvim_buf_get_lines(buf, token.line, token.line + 1, false)[1] or ""
    local col = token.end_col
    while col < #line do
      local next_col = col + 1
      for _, t in ipairs(st.get_at_pos(buf, token.line, col) or {}) do
        if t.client_id == client_id and t.line == token.line and t.start_col == col and not t.marked then
          t.marked = true -- nvim's own flag: don't redo it when the fold opens
          st.highlight_token(t, buf, client_id, ("@lsp.type.%s.%s"):format(t.type, ft), { priority = priority })
          for modifier in pairs(t.modifiers) do
            st.highlight_token(t, buf, client_id, ("@lsp.mod.%s.%s"):format(modifier, ft), { priority = priority + 1 })
            st.highlight_token(t, buf, client_id, ("@lsp.typemod.%s.%s.%s"):format(t.type, modifier, ft), { priority = priority + 2 })
          end
          vim.api.nvim_exec_autocmds("LspTokenUpdate", { buffer = buf, modeline = false, data = { token = t, client_id = client_id } })
          next_col = math.max(next_col, t.end_col)
        end
      end
      col = next_col
    end
  end,
})

vim.api.nvim_create_autocmd("LspTokenUpdate", {
  callback = function(args)
    local token, buf, client_id = args.data.token, args.buf, args.data.client_id
    local line = vim.api.nvim_buf_get_lines(buf, token.line, token.line + 1, false)[1]
    if not line then
      return
    end
    local text = line:sub(token.start_col + 1, token.end_col)
    local function paint(start_col, end_col, group)
      local piece = vim.deepcopy(token)
      piece.start_col, piece.end_col = start_col, end_col
      vim.lsp.semantic_tokens.highlight_token(piece, buf, client_id, group, { priority = 128 })
    end

    if text:match "^[%p]+$" then
      paint(token.start_col, token.end_col, "@operator")
      return
    end

    -- generic parameters are plain in Xcode, wherever they're declared:
    -- <Content: View> here, or Binding's Value in `extension Binding where Value == Bool`
    if token.type == "typeParameter" then
      paint(token.start_col, token.end_col, "@variable")
      return
    end

    if token.type == "variable" and not token.modifiers.defaultLibrary then
      if not is_local(buf, token.line, token.start_col, text) then
        paint(token.start_col, token.end_col, "@lsp.type.property") -- global: project member color
      end
      return
    end

    local apple = token.modifiers.defaultLibrary
    local group = apple and ("@lsp.typemod." .. token.type .. ".defaultLibrary") or ("@lsp.type." .. token.type)

    if token.start_col > 0 and line:sub(token.start_col, token.start_col):match "[@#]" then
      paint(token.start_col - 1, token.start_col, group)
    end

    if vim.tbl_contains({ "struct", "class", "enum", "method", "function", "macro" }, token.type) then
      -- regular extmarks in their own namespace: token highlights are redrawn
      -- line by line, which would drop labels on the call's later lines
      for _, r in ipairs(argument_labels(buf, token.line, token.end_col)) do
        pcall(vim.api.nvim_buf_set_extmark, buf, label_ns, r[1], r[2], {
          end_col = r[3],
          hl_group = group,
          priority = 128,
        })
      end
    end
  end,
})

-- labels are recomputed when sourcekit sends new tokens after an edit
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
  callback = function(args)
    vim.api.nvim_buf_clear_namespace(args.buf, label_ns, 0, -1)
  end,
})

-- rust_analyzer: from rustup (`rustup component add rust-analyzer`), so it
-- matches the toolchain
local servers = { "html", "cssls", "sourcekit", "rust_analyzer" }
vim.lsp.enable(servers)

-- read :h vim.lsp.config for changing options of lsp servers
