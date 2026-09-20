return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- The colours come from the active colorscheme's highlight groups.
		--
		-- They used to come from `require("rose-pine.palette")`, which had three
		-- consequences. The statusline stayed Rosé Pine whichever theme was
		-- selected, so `theme catppuccin-mocha` recoloured the editor and left
		-- the bar at the bottom of it alone. It pinned rose-pine/neovim as a
		-- dependency of lualine, so the plugin could not be uninstalled even
		-- when nothing was using it as a colorscheme. And it named that
		-- dependency without a `name`, while plugins/ui/colorscheme.lua names
		-- the same repository `rose-pine` — lazy.nvim keys plugins by name, so
		-- it treated them as two plugins and kept a second clone of the
		-- repository in lazy/neovim next to lazy/rose-pine.
		--
		-- These groups are ones every colorscheme sets, so this follows any
		-- scheme including one added after this was written. Under Rosé Pine
		-- they resolve to the exact palette entries this file used to name by
		-- hand: Normal is base and text, CursorLine is overlay, Comment is
		-- subtle, Function is rose, Keyword is pine, DiagnosticError is love,
		-- DiagnosticWarn is gold and DiagnosticHint is iris.
		local function hl(group, attr, fallback)
			local h = vim.api.nvim_get_hl(0, { name = group, link = false })
			return h[attr] and string.format("#%06x", h[attr]) or fallback
		end

		-- Fallbacks are only reached by a colorscheme that leaves one of these
		-- unset, which would otherwise hand lualine a nil and raise inside the
		-- statusline where the error is redrawn every keystroke.
		local function palette()
			return {
				base = hl("Normal", "bg", "#000000"),
				overlay = hl("CursorLine", "bg", "#222222"),
				text = hl("Normal", "fg", "#ffffff"),
				subtle = hl("Comment", "fg", "#888888"),
				-- One per mode, picked to stay distinct from each other in
				-- every variant of both schemes rather than to match the name
				-- of the group.
				normal = hl("Function", "fg", "#ffffff"),
				insert = hl("Keyword", "fg", "#88aaff"),
				visual = hl("DiagnosticError", "fg", "#ff8888"),
				command = hl("DiagnosticWarn", "fg", "#ffcc88"),
				replace = hl("DiagnosticHint", "fg", "#cc88ff"),
			}
		end

		local function build()
			local colors = palette()
			local theme = {
				normal = {
					a = { fg = colors.normal, bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
					c = { fg = colors.text, bg = colors.overlay },
					x = { fg = colors.text, bg = colors.overlay },
					y = { fg = colors.text, bg = colors.overlay },
					z = { fg = colors.text, bg = colors.overlay },
				},
				insert = {
					a = { fg = colors.insert, bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
					c = { fg = colors.text, bg = colors.overlay },
					x = { fg = colors.text, bg = colors.overlay },
					y = { fg = colors.text, bg = colors.overlay },
					z = { fg = colors.text, bg = colors.overlay },
				},
				visual = {
					a = { fg = colors.visual, bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
					c = { fg = colors.text, bg = colors.overlay },
					x = { fg = colors.text, bg = colors.overlay },
					y = { fg = colors.text, bg = colors.overlay },
					z = { fg = colors.text, bg = colors.overlay },
				},
				command = {
					a = { fg = colors.command, bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
					c = { fg = colors.text, bg = colors.overlay },
					x = { fg = colors.text, bg = colors.overlay },
					y = { fg = colors.text, bg = colors.overlay },
					z = { fg = colors.text, bg = colors.overlay },
				},
				replace = {
					a = { fg = colors.replace, bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
					c = { fg = colors.text, bg = colors.overlay },
					x = { fg = colors.text, bg = colors.overlay },
					y = { fg = colors.text, bg = colors.overlay },
					z = { fg = colors.text, bg = colors.overlay },
				},
			}
			local empty = require("lualine.component"):extend()
			function empty:draw(default_highlight)
				self.status = ""
				self.applied_separator = ""
				self:apply_highlights(default_highlight)
				self:apply_section_separators()
				return self.status
			end

			-- Put proper separators and gaps between components in sections
			local function process_sections(sections)
				for name, section in pairs(sections) do
					local left = name:sub(9, 10) < "x"
					for pos = 1, name ~= "lualine_z" and #section or #section - 1 do
						table.insert(
							section,
							pos * 2,
							{ empty, color = { fg = colors.base, bg = colors.base } }
						)
					end
					for id, comp in ipairs(section) do
						if type(comp) ~= "table" then
							comp = { comp }
							section[id] = comp
						end
						comp.separator = left and { right = "" } or { left = "" }
					end
				end
				return sections
			end

			local function search_result()
				if vim.v.hlsearch == 0 then
					return ""
				end
				local last_search = vim.fn.getreg("/")
				if not last_search or last_search == "" then
					return ""
				end
				local searchcount = vim.fn.searchcount({ maxcount = 9999 })
				return last_search
					.. "("
					.. searchcount.current
					.. "/"
					.. searchcount.total
					.. ")"
			end

			local function modified()
				if vim.bo.modified then
					return "+"
				elseif vim.bo.modifiable == false or vim.bo.readonly == true then
					return "-"
				end
				return ""
			end

			local function macro_rec_status()
				local reg = vim.fn.reg_recording()
				if reg ~= "" then
					return "Recording @" .. reg
				else
					local mode = vim.api.nvim_get_mode().mode
					local mode_map = {
						n = "NORMAL",
						i = "INSERT",
						v = "VISUAL",
						V = "V-LINE",
						["\22"] = "V-BLOCK",
						c = "COMMAND",
						R = "REPLACE",
						s = "SELECT",
						S = "S-LINE",
						["\19"] = "S-BLOCK",
						t = "TERMINAL",
					}
					return mode_map[mode] or mode:upper()
				end
			end

			require("lualine").setup({
				options = {
					theme = theme,
					component_separators = "",
					section_separators = { left = "", right = "" },
				},
				sections = process_sections({
					lualine_a = {
						{ macro_rec_status },
						{ modified, color = { fg = colors.normal, bg = colors.overlay } },
					},
					lualine_b = {
						{
							"diagnostics",
							source = { "nvim" },
							sections = { "error" },
							diagnostics_color = {
								error = { bg = colors.command, fg = colors.text },
							},
						},
						{
							"diagnostics",
							source = { "nvim" },
							sections = { "warn" },
							diagnostics_color = {
								warn = { bg = colors.command, fg = colors.text },
							},
						},
					},
					lualine_c = {
						-- 'branch',
						-- 'diff',
						{
							"%w",
							cond = function()
								return vim.wo.previewwindow
							end,
						},
						{
							"%r",
							cond = function()
								return vim.bo.readonly
							end,
						},
						{
							"%q",
							cond = function()
								return vim.bo.buftype == "quickfix"
							end,
						},
					},
					lualine_x = { "%p%%(%l/%L), %c" },
					lualine_y = { { "filename", file_status = false, path = 1 } },
					lualine_z = { search_result, "filetype" },
				}),
				inactive_sections = {
					lualine_c = { "%f %y %m" },
					lualine_x = {},
				},
			})
		end

		vim.schedule(build)

		-- Reading the groups only once would leave the bar on the colours of
		-- whichever scheme happened to load first, which is the bug this file
		-- just stopped having. `theme` needs nvim restarted either way, but
		-- `:colorscheme` typed at runtime is followed now.
		vim.api.nvim_create_autocmd("ColorScheme", {
			desc = "Rebuild the statusline for the new colorscheme",
			callback = function()
				vim.schedule(build)
			end,
		})
	end,
}
