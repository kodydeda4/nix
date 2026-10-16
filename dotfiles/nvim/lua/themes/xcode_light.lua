-- Xcode 26's default light theme (what Xcode uses in light mode), with the same
-- highlighting rules as xcode_dark (configs/xcode_theme.lua). Xcode generates
-- this theme in code, so the colors were sampled from a screenshot; strings,
-- numbers, comments and #if weren't on screen and come from the classic
-- Default (Light) theme.

return require "configs.xcode_theme"("xcode_light", "light", {
  bg = "#ffffff",
  current_line = "#efefef",
  selection = "#b2d7ff", -- sampled from Xcode 26
  text = "#30282b",
  comment = "#5d6c79",
  keyword = "#ad3068",
  string = "#c41a16",
  number = "#1c00cf",
  preprocessor = "#643820",
  attribute = "#815f03",
  url = "#0e0eff",
  type_declaration = "#16768e", -- struct AppFeature
  other_declaration = "#155b6b", -- var developer, case view
  type = "#8d3faf", -- Apple's types (Sendable, Result)
  member = "#77127f", -- Apple's functions / properties (.scenePhase)
  project_type = "#177a68", -- your (and packages') types
  project_member = "#146257", -- your (and packages') functions / properties, @Presents
  line_number = "#b4b3b4",
  warning = "#d68a00", -- amber, like dark mode's gold (number is blue here)
  folder = "#3a8ee6",
})
