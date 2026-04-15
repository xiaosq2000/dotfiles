return {
	"OXY2DEV/markview.nvim",
	lazy = false,
	dependencies = { "saghen/blink.cmp" },
	opts = {
		markdown = {
			list_items = {
				shift_width = 2,
			},
		},
	},
	init = function()
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "markdown",
			callback = function()
				vim.opt_local.wrap = false
			end,
		})
		vim.api.nvim_set_keymap(
			"n",
			"<leader>m",
			"<CMD>Markview<CR>",
			{ desc = "Toggles `markview` previews globally." }
		)
	end,
}
