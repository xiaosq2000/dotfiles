return {
	"folke/todo-comments.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		require("todo-comments").setup({
			-- Supports doxygen tags. Reference: https://github.com/folke/todo-comments.nvim/issues/30
			keywords = {
				FIX = {
					icon = " ", -- icon used for the sign, and in search results
					color = "error", -- can be a hex color, or a named color (see below)
					alt = { "FIXME", "BUG", "FIXIT", "ISSUE" }, -- a set of other keywords that all map to this FIX keywords
					-- signs = false, -- configure signs for some keywords individually
				},
				TODO = { icon = " ", color = "info", alt = { "todo" } },
				HACK = { icon = " ", color = "warning" },
				WARN = { icon = " ", color = "warning", alt = { "warn", "WARNING", "warning" } },
				PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
				NOTE = { icon = " ", color = "hint", alt = { "INFO", "note" } },
				TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
				PARAM = { icon = "", alt = { "param", "return" } },
				DESC = { icon = "", color = "hint", alt = { "brief", "par", "file" } },
			},
			highlight = {
				before = "", -- "fg" or "bg" or empty
				keyword = "wide", -- "fg", "bg", "wide" or empty. (wide is the same as bg, but will also highlight surrounding characters)
				after = "fg", -- "fg" or "bg" or empty
				pattern = { [[.*<(KEYWORDS)\s*:]], [[.*\@(KEYWORDS)\s*]] },
				comments_only = true, -- uses treesitter to match keywords in comments only
			},
			search = {
				command = "rg",
				args = {
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
				},
				pattern = [[[\\\\@]*\b(KEYWORDS)(\s|:)]],
			},
		})
	end,
}
