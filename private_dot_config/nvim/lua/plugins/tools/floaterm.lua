return {
	"voldikss/vim-floaterm",
	cond = not require("core.env").kitty_scrollback,
	cmd = { "FloatermToggle", "FloatermNew", "FloatermPrev", "FloatermNext" },
	keys = {
		{ "<F1>", "<cmd>FloatermToggle<cr>", desc = "Toggle floating terminal" },
		{
			"<F1>",
			[[<C-\><C-n><cmd>FloatermToggle<cr>]],
			mode = "t",
			desc = "Toggle floating terminal",
		},
		{ "<F2>", "<cmd>FloatermNew<cr>", desc = "New floating terminal" },
		{
			"<F2>",
			[[<C-\><C-n><cmd>FloatermNew<cr>]],
			mode = "t",
			desc = "New floating terminal",
		},
		{ "<F3>", "<cmd>FloatermPrev<cr>", desc = "Previous floating terminal" },
		{
			"<F3>",
			[[<C-\><C-n><cmd>FloatermPrev<cr>]],
			mode = "t",
			desc = "Previous floating terminal",
		},
		{ "<F4>", "<cmd>FloatermNext<cr>", desc = "Next floating terminal" },
		{
			"<F4>",
			[[<C-\><C-n><cmd>FloatermNext<cr>]],
			mode = "t",
			desc = "Next floating terminal",
		},
	},
	init = function()
		vim.g.floaterm_width = 0.85
		vim.g.floaterm_height = 0.85
		vim.g.floaterm_autoclose = 2
		vim.g.floaterm_title = "Terminal: $1/$2"
		vim.g.floaterm_titleposition = 2
	end,
}
