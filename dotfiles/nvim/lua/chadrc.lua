-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	-- the theme in use right now; it follows macOS light / dark mode (configs/appearance.lua)
	theme = "xcode_light",
	-- what light and dark mode use; Space t h saves your pick to the current mode's
	theme_dark = "xcode_dark",
	theme_light = "xcode_light",
	-- syntax colors for everything but Swift (the rest of the UI stays the theme
	-- above; configs/code_syntax.lua)
	code_theme_dark = "onedark",
	code_theme_light = "one_light",
	-- Space t t switches between these (matches Ghostty atom-one-dark-oled / Atom One Light)
	theme_toggle = { "xcode_light", "one_light" },
	transparency = false,

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

	-- (the file tree's selected row is set in configs/xcode_theme.lua)

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },
}

-- M.nvdash = { load_on_startup = true }

-- blank space as wide as the file tree (and the column next to it), so the
-- tab bar starts where the editor does; "" when the tree is closed
local function tree_offset(hl)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NvimTree" then
			-- the last column sits over the solid divider next to the tree
			return "%#" .. hl .. "#" .. string.rep(" ", vim.api.nvim_win_get_width(win)) .. "%#XcodeEditor# "
		end
	end
	return ""
end

M.ui = {
	tabufline = {
		-- always show the tab bar, even with one file open (NvChad hides it
		-- until there are two)
		lazyload = false,
		-- no theme-toggle / close-all buttons on the right ("btns")
		order = { "treeOffset", "buffers", "tabs" },
		modules = {
			-- the blank block above the file tree: glass like the tree itself,
			-- with no divider (NvChad draws it in the tab bar's grey, plus a │)
			treeOffset = function()
				return tree_offset "NvimTreeNormal"
			end,

			-- NvChad's open-file tabs, except that with the cursor in the file
			-- tree the file you came from still shows as the selected tab
			buffers = function()
				local api = vim.api
				local style_buf = require("nvchad.tabufline.utils").style_buf
				local width = require("nvconfig").ui.tabufline.bufwidth

				local selected = api.nvim_get_current_buf()
				local in_tree = vim.bo[selected].filetype == "NvimTree"
				if in_tree then
					local prev = vim.fn.win_getid(vim.fn.winnr "#")
					selected = prev ~= 0 and api.nvim_win_get_buf(prev) or selected
				end

				local space = vim.o.columns - api.nvim_eval_statusline(tree_offset "NvimTreeNormal", { use_tabline = true }).width
				vim.t.bufs = vim.tbl_filter(api.nvim_buf_is_valid, vim.t.bufs or {})
				local tabs, has_selected = {}, false
				for i, nr in ipairs(vim.t.bufs) do
					-- too many to fit: drop tabs from the left until the selected one shows
					if (#tabs + 1) * width > space then
						if has_selected then
							break
						end
						table.remove(tabs, 1)
					end
					has_selected = has_selected or nr == selected
					local tab = style_buf(nr, i, width)
					if in_tree and nr == selected then
						tab = tab:gsub("BufOff", "BufOn") -- draw it as the current tab
						-- its icon color on the selected background may not exist yet
						for group in tab:gmatch "%%#([%w_]+)BufOn#" do
							if group ~= "Tb" and vim.fn.hlexists(group .. "BufOn") == 0 then
								api.nvim_set_hl(0, group .. "BufOn", {
									fg = api.nvim_get_hl(0, { name = group }).fg,
									bg = api.nvim_get_hl(0, { name = "TbBufOn" }).bg,
								})
							end
						end
					elseif nr ~= selected then
						-- inactive tab: its file icon in the tab's dim text color, not
						-- the icon's own color (options.lua dims the rest)
						tab = tab:gsub("%%#DevIcon[%w_]*BufOff#", "%%#TbBufOff#")
					end
					table.insert(tabs, tab)
				end
				return table.concat(tabs) .. "%#TbFill#%="
			end,
		},
	},

	-- outline Telescope's panels (find files, live grep...) instead of flat blocks
	telescope = { style = "bordered" },

	statusline = {
		-- just mode, git, LSP progress and diagnostics, under the file tree
		-- (configs/sidebar_status.lua)
		order = { "sidebar" },
		modules = {
			sidebar = function()
				return require "configs.sidebar_status"()
			end,
		},
		-- default layout and colors, but no separator glyphs: options.lua turns
		-- every colored block into colored text on black (all modes)
		separator_style = { left = " ", right = " " },
	},
}

return M
