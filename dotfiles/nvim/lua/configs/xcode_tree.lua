-- nvim-tree decorator: icons like Xcode's project navigator.
--  * folders with a Package.swift (Swift packages): tan box
--  * .xcodeproj / .xcworkspace: blue project icon
-- Plain folders keep the normal folder icon (blue in xcode_dark).

local hl = vim.api.nvim_set_hl
local function define_colors()
  -- default = true: a theme can set these groups itself
  hl(0, "XcodeTreePackage", { fg = "#d6b47f", default = true })
  hl(0, "XcodeTreeProject", { fg = "#4a9ff5", default = true })
end
define_colors()
vim.api.nvim_create_autocmd("ColorScheme", { callback = define_colors })

local is_package = {} -- absolute path -> boolean

local XcodeDecorator = require("nvim-tree.api").Decorator:extend()

function XcodeDecorator:new()
  self.enabled = true
  self.highlight_range = "none"
  self.icon_placement = "none"
  self.package_icon = { str = vim.fn.nr2char(0xF03D7), hl = { "XcodeTreePackage" } } -- box (md-package-variant-closed)
  self.project_icon = { str = "󰣪", hl = { "XcodeTreeProject" } }
end

function XcodeDecorator:icon_node(node)
  if node.type ~= "directory" then
    return nil
  end
  if node.name:match "%.xcodeproj$" or node.name:match "%.xcworkspace$" then
    return self.project_icon
  end
  local path = node.absolute_path
  if is_package[path] == nil then
    is_package[path] = vim.uv.fs_stat(path .. "/Package.swift") ~= nil
  end
  return is_package[path] and self.package_icon or nil
end

return XcodeDecorator
