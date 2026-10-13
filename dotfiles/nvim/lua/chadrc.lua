-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "onedark",
	-- Space t t switches between these (matches Ghostty atom-one-dark-oled / Atom One Light)
	theme_toggle = { "onedark", "one_light" },
	-- Space t b flips this (and rewrites this line so it sticks across restarts)
	transparency = true,

	-- match Ghostty's atom-one-dark-oled: pure black background, its text and
	-- selection colors; everything else is NvChad's onedark
	changed_themes = {
		onedark = {
			base_30 = {
				black = "#000000",
				darker_black = "#0f0f12", -- sidebar (nvim-tree) and floats: deep grey
				white = "#e0def4",
				statusline_bg = "#000000", -- OLED status bar
			},
			base_16 = { base00 = "#000000", base02 = "#191724", base05 = "#e0def4" },
		},
	},

	hl_override = {
		-- selected row in the file tree: a step lighter than the deep grey sidebar
		-- (NvChad uses the editor background, which is pure black here)
		NvimTreeCursorLine = { bg = "#1c1c22" },
	},

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- M.nvdash = { load_on_startup = true }

M.ui = {
	statusline = {
		-- default layout and colors, but no separator glyphs: options.lua turns
		-- every colored block into colored text on black (all modes)
		separator_style = { left = " ", right = " " },
	},
}

return M
