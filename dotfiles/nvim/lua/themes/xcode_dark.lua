-- Kody's Xcode 26 theme ("Xcode 26 2" in Xcode's Fonts & Colors), converted
-- from that theme's file. The highlighting rules are in configs/xcode_theme.lua;
-- copy this file to make another theme with different colors.

return require "configs.xcode_theme"("xcode_dark", "dark", {
  bg = "#060607",
  current_line = "#2f3239",
  selection = "#2e3a52", -- Xcode uses #646f83, too strong on whole terminal lines
  text = "#dfdfe0",
  comment = "#7f8c98",
  keyword = "#ff7ab2",
  string = "#ff8170",
  number = "#d9c97c",
  preprocessor = "#ffa14f",
  attribute = "#cc9768",
  url = "#6699ff",
  type_declaration = "#6bdfff",
  other_declaration = "#4eb0cc",
  type = "#dabaff", -- Apple's types
  member = "#b281eb", -- Apple's functions / properties
  project_type = "#acf2e4", -- your (and packages') types
  project_member = "#78c2b3", -- your (and packages') functions / properties
  separator = "#3a3a42", -- pane dividers

  -- the exact UI shades this theme had before the template
  ui = {
    darker_black = "#18181c",
    black2 = "#26262c",
    one_bg = "#28282e",
    one_bg2 = "#323239",
    one_bg3 = "#3a3a42",
    grey = "#47474f",
    grey_fg = "#5c5c66",
    grey_fg2 = "#6c6c76",
    light_grey = "#7f7f89",
    baby_pink = "#ff8bb6",
    line = "#2c2c33",
    green = "#67b7a4",
    vibrant_green = "#9ef1dd",
    sun = "#e5d58a",
    statusline_bg = "#1a1a1f",
    lightbg = "#2b2b31",
  },
  base_16 = {
    base01 = "#2a2a30",
    base04 = "#8a94a0",
    base06 = "#ededee",
    base07 = "#ffffff",
  },
})
