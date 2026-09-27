return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- The colours come from highlight groups every colorscheme sets, so the
		-- bar follows whichever theme is active instead of naming one palette.
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

			-- Modes differ only in the colour of section a.
			local theme = {}
			local modes = { "normal", "insert", "visual", "command", "replace" }
			for _, mode in ipairs(modes) do
				theme[mode] = {
					a = { fg = colors[mode], bg = colors.overlay, gui = "bold" },
					b = { fg = colors.subtle, bg = colors.overlay, gui = "bold" },
				}
				for _, section in ipairs({ "c", "x", "y", "z" }) do
					theme[mode][section] = { fg = colors.text, bg = colors.overlay }
				end
			end

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

			local function modified()
				if vim.bo.modified then
					return "+"
				elseif vim.bo.modifiable == false or vim.bo.readonly == true then
					return "-"
				end
				return ""
			end

			require("lualine").setup({
				options = {
					theme = theme,
					component_separators = "",
					section_separators = { left = "", right = "" },
				},
				sections = process_sections({
					lualine_a = {
						{
							"mode",
							-- 'cmdheight' is 0, so this is the only place a
							-- running macro shows.
							fmt = function(mode)
								local reg = vim.fn.reg_recording()
								return reg ~= "" and "Recording @" .. reg or mode
							end,
						},
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
					lualine_z = {
						{
							"searchcount",
							maxcount = 9999,
							-- Prefix the pattern: `foo[2/7]`.
							fmt = function(count)
								return count ~= "" and vim.fn.getreg("/") .. count or ""
							end,
						},
						"filetype",
					},
				}),
				inactive_sections = {
					lualine_c = { "%f %y %m" },
					lualine_x = {},
				},
			})
		end

		vim.schedule(build)

		-- Rebuild on :colorscheme so the bar follows a scheme switched at runtime.
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("user.lualine", { clear = true }),
			desc = "Rebuild the statusline for the new colorscheme",
			callback = function()
				vim.schedule(build)
			end,
		})
	end,
}
