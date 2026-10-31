-- Template for Xcode-style NvChad themes: all the syntax highlighting rules
-- (your code vs Apple's, attributes, labels, declarations, file tree...) live
-- here; a theme in lua/themes/ only picks the colors. See xcode_dark.lua.
--
-- Usage, in lua/themes/<name>.lua:
--   return require "configs.xcode_theme" ("<name>", "dark" or "light", {
--     bg, current_line, selection, text, comment, keyword, string, number,
--     preprocessor, attribute, url, type_declaration, other_declaration,
--     type, member, project_type, project_member,
--     -- optional:
--     separator, folder, line_number, warning (defaults to number),
--     ui = { ...base46 base_30 overrides (darker_black, black2, grey...) },
--     base_16 = { ...base46 base_16 overrides },
--   })
-- Background shades (sidebar, floats, borders...) are blended from bg and text
-- unless `ui` sets them, so light themes work without listing them.

local mix = require("base46.colors").mix

return function(name, kind, c)
  local function shade(percent)
    return mix(c.bg, c.text, percent)
  end
  c.separator = c.separator or shade(20)
  c.folder = c.folder or "#5ab3f4"

  local M = {}

  M.base_30 = vim.tbl_extend("force", {
    white = c.text,
    darker_black = shade(6),
    black = c.bg, -- nvim bg
    black2 = shade(12),
    one_bg = shade(13),
    one_bg2 = shade(17),
    one_bg3 = shade(20),
    grey = shade(25),
    grey_fg = shade(33),
    grey_fg2 = shade(40),
    light_grey = shade(48),
    red = c.string,
    baby_pink = c.keyword,
    pink = c.keyword,
    line = shade(15),
    green = c.project_member,
    vibrant_green = c.project_type,
    nord_blue = c.url,
    blue = c.type_declaration,
    yellow = c.warning or c.number, -- warnings
    sun = c.warning or c.number,
    purple = c.type,
    dark_purple = c.member,
    teal = c.other_declaration,
    orange = c.preprocessor,
    cyan = c.type_declaration,
    statusline_bg = shade(7),
    lightbg = shade(14),
    pmenu_bg = c.type_declaration,
    folder_bg = c.type_declaration,
  }, c.ui or {})

  M.base_16 = vim.tbl_extend("force", {
    base00 = c.bg,
    base01 = shade(13),
    base02 = c.selection,
    base03 = c.comment,
    base04 = shade(55),
    base05 = c.text,
    base06 = c.text,
    base07 = c.text,
    base08 = c.string,
    base09 = c.number,
    base0A = c.type,
    base0B = c.string,
    base0C = c.type_declaration,
    base0D = c.member,
    base0E = c.keyword,
    base0F = c.preprocessor,
  }, c.base_16 or {})

  local keyword = { fg = c.keyword, bold = true }

  -- the editor's background: solid, or none with Space t b's see-through
  -- editor on (a flag file, mappings.lua), so the glass shows behind the code too
  local editor_bg = vim.fn.filereadable(vim.fn.stdpath "state" .. "/editor-glass") == 1 and "NONE" or c.bg

  M.polish_hl = {
    defaults = {
      -- Normal has no background, so Ghostty's glass shows through (the file
      -- tree); editor windows get the solid XcodeEditor instead (configs/glass.lua)
      Normal = { fg = c.text, bg = "NONE" },
      XcodeEditor = { fg = c.text, bg = editor_bg },
      -- the gutter takes Normal's (empty) background unless given its own
      LineNr = { fg = c.line_number or shade(25), bg = editor_bg },
      CursorLineNr = { fg = c.text, bg = editor_bg },
      SignColumn = { bg = editor_bg },
      FoldColumn = { bg = editor_bg },
      -- no background of its own: empty rows past the end of a buffer take their
      -- window's (the solid editor, or a popup's own, e.g. which-key's)
      EndOfBuffer = { fg = c.bg },
      -- the tab bar's base: no background, so the glass shows through (the
      -- tabs have their own colors)
      TabLineFill = { bg = "NONE" },
      CursorLine = { bg = c.current_line },
      Visual = { bg = c.selection },
      WinSeparator = { fg = c.separator, bg = editor_bg }, -- between splits
      -- folded lines: a faint band (NvChad's grey is too strong)
      Folded = { bg = shade(kind == "light" and 4 or 6) },
      -- selected suggestion in popup menus (completion too): your selection
      -- color with normal text, not NvChad's black on bright cyan
      PmenuSel = { fg = c.text, bg = c.selection },
    },

    -- file tree like Xcode's navigator: blue folder icons, plain names
    nvimtree = {
      -- selected row: a soft grey, like Xcode's navigator
      NvimTreeCursorLine = { bg = kind == "light" and "#dcdce0" or "#28292e" },
      NvimTreeFolderIcon = { fg = c.folder },
      NvimTreeFolderName = { fg = c.text },
      NvimTreeOpenedFolderName = { fg = c.text },
      NvimTreeEmptyFolderName = { fg = c.text },
      NvimTreeFolderArrowOpen = { fg = c.comment },
      NvimTreeFolderArrowClosed = { fg = c.comment },
      -- no background: Ghostty's glass shows through, like Xcode's sidebar.
      -- (A text color too: a group with only bg = NONE counts as empty, and
      -- nvim-tree then links it to Normal.)
      NvimTreeNormal = { fg = c.text, bg = "NONE" },
      NvimTreeNormalNC = { fg = c.text, bg = "NONE" },
      NvimTreeEndOfBuffer = { fg = c.bg, bg = "NONE" },
      NvimTreeSignColumn = { fg = c.text, bg = "NONE" },
      -- the column between the tree and the editor (where you drag to resize):
      -- in the editor's background
      NvimTreeWinSeparator = { fg = c.bg, bg = editor_bg },
    },

    -- indent guide lines: fainter than NvChad's, so they don't compete with
    -- the code (the current scope's line a step stronger)
    blankline = {
      IblChar = { fg = shade(9) },
      IblScopeChar = { fg = shade(18) },
    },

    -- completion menu: the letters you typed stand out by being brighter and
    -- bold instead of cyan (the selected row is PmenuSel, above)
    blink = {
      BlinkCmpLabel = { fg = shade(75) },
      BlinkCmpLabelMatch = { fg = c.text, bold = true },
      BlinkCmpSignatureHelpActiveParameter = { fg = c.text, bold = true },
    },

    syntax = {
      Include = keyword, -- NvChad links @keyword.import (import) to this
    },

    treesitter = {
      ["@keyword"] = keyword,
      ["@keyword.function"] = keyword,
      ["@keyword.return"] = keyword,
      ["@keyword.conditional"] = keyword,
      ["@keyword.conditional.ternary"] = { fg = c.text }, -- a ? b : c
      ["@keyword.repeat"] = keyword,
      ["@keyword.import"] = keyword,
      ["@keyword.modifier"] = keyword,
      ["@keyword.type"] = keyword,
      ["@keyword.coroutine"] = keyword,
      ["@keyword.exception"] = keyword,
      ["@keyword.operator"] = keyword,
      ["@keyword.storage"] = keyword,
      ["@boolean"] = keyword,
      ["@variable.builtin"] = keyword, -- self
      ["@constant.builtin"] = keyword, -- nil
      ["@keyword.directive"] = { fg = c.preprocessor }, -- #if
      -- Names whose color depends on what they are (your code or Apple's) start
      -- plain, like in Xcode; sourcekit's semantic tokens color them once the
      -- file is analyzed (see the @lsp groups below).
      ["@function.macro"] = { fg = c.text }, -- #Preview
      ["@constant.macro"] = { fg = c.preprocessor },

      ["@string"] = { fg = c.string },
      ["@string.escape"] = { fg = c.string },
      ["@string.regexp"] = { fg = c.string },
      ["@character"] = { fg = c.number },
      ["@character.special"] = { fg = c.number },
      ["@number"] = { fg = c.number },
      ["@number.float"] = { fg = c.number },

      ["@comment"] = { fg = c.comment },
      ["@comment.documentation"] = { fg = c.comment },

      ["@attribute"] = { fg = c.text },
      ["@attribute.type"] = { fg = c.text }, -- @State, @Bindable, @Environment
      ["@attribute.builtin"] = { fg = c.attribute }, -- @objc, @available
      ["@attribute.sendable"] = keyword, -- @Sendable
      ["@attribute.macro"] = { fg = c.text }, -- @Observable, @Model
      ["@attribute.project"] = { fg = c.text }, -- @Dependency, @Shared, @Reducer

      ["@type"] = { fg = c.text },
      ["@type.builtin"] = { fg = c.text },
      ["@constructor"] = { fg = c.text },
      ["@type.definition"] = { fg = c.type_declaration }, -- struct Foo

      ["@function"] = { fg = c.other_declaration },
      ["@function.method"] = { fg = c.other_declaration }, -- func foo()
      ["@function.call"] = { fg = c.text },
      ["@function.method.call"] = { fg = c.text },

      ["@variable"] = { fg = c.text },
      ["@variable.parameter"] = { fg = c.text },
      ["@variable.parameter.definition"] = { fg = c.other_declaration }, -- init(store:)
      ["@variable.member"] = { fg = c.text }, -- .padding, store.state
      ["@variable.member.definition"] = { fg = c.other_declaration }, -- var foo in a type
      ["@property"] = { fg = c.text },
      ["@label"] = { fg = c.text },
      ["@label.argument"] = { fg = c.text }, -- until sourcekit colors them (lspconfig.lua)

      ["@operator"] = { fg = c.text },
      ["@punctuation.bracket"] = { fg = c.text },
      ["@punctuation.delimiter"] = { fg = c.text },
      ["@punctuation.special"] = { fg = c.text },
      ["@module"] = { fg = c.text },
      ["@variable.member.implicit"] = { fg = c.text }, -- .send(.task)
      ["@variable.member.keypath"] = { fg = c.text }, -- \.list
      ["@label.trailing"] = { fg = c.member }, -- } actions: {

      -- sourcekit-lsp semantic tokens (lspconfig.lua): your code vs Apple's
      -- (defaultLibrary). They outrank the treesitter colors above.
      ["@lsp.type.struct"] = { fg = c.project_type },
      ["@lsp.type.class"] = { fg = c.project_type },
      ["@lsp.type.enum"] = { fg = c.project_type },
      ["@lsp.type.interface"] = { fg = c.project_type },
      ["@lsp.type.type"] = { fg = c.project_type },
      ["@lsp.type.typeParameter"] = { fg = c.project_type },
      ["@lsp.typemod.struct.defaultLibrary"] = { fg = c.type },
      ["@lsp.typemod.class.defaultLibrary"] = { fg = c.type },
      ["@lsp.typemod.enum.defaultLibrary"] = { fg = c.type },
      ["@lsp.typemod.interface.defaultLibrary"] = { fg = c.type },
      ["@lsp.typemod.type.defaultLibrary"] = { fg = c.type },
      ["@lsp.typemod.typeParameter.defaultLibrary"] = { fg = c.type },

      ["@lsp.type.method"] = { fg = c.project_member },
      ["@lsp.type.function"] = { fg = c.project_member },
      ["@lsp.type.property"] = { fg = c.project_member },
      ["@lsp.type.enumMember"] = { fg = c.project_member },
      ["@lsp.typemod.method.defaultLibrary"] = { fg = c.member },
      ["@lsp.typemod.function.defaultLibrary"] = { fg = c.member },
      ["@lsp.typemod.property.defaultLibrary"] = { fg = c.member },
      ["@lsp.typemod.enumMember.defaultLibrary"] = { fg = c.member },
      ["@lsp.typemod.variable.defaultLibrary"] = { fg = c.member },

      -- locals, parameters and operators stay plain text, like in Xcode
      ["@lsp.type.variable"] = { fg = c.text },
      ["@lsp.type.parameter"] = { fg = c.text },
      ["@lsp.type.operator"] = { fg = c.text },
      ["@lsp.typemod.operator.defaultLibrary"] = { fg = c.text },
      -- macros (@ObservableState, @Presents; Apple's @State) take the member colors
      ["@lsp.type.macro"] = { fg = c.project_member },
      ["@lsp.typemod.macro.defaultLibrary"] = { fg = c.member },
    },
  }

  M.type = kind

  return require("base46").override_theme(M, name)
end
