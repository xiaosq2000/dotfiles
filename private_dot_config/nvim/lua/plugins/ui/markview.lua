return {
	"OXY2DEV/markview.nvim",
	-- The author recommends against lazy-loading: markview manages its own
	-- filetype attachment and needs to be present when the buffer is created.
	lazy = false,
	dependencies = { "saghen/blink.cmp" },
	opts = {
		markdown = {
			list_items = {
				shift_width = 2,
			},
		},
	},
	keys = {
		{ "<leader>m", "<cmd>Markview<cr>", desc = "Toggle markview previews" },
	},
	init = function()
		-- Rendered markdown reads better unwrapped, overriding the global default.
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("user.markview", { clear = true }),
			pattern = "markdown",
			callback = function()
				vim.opt_local.wrap = false
			end,
		})
	end,
}
