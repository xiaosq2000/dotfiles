return {
	{
		"voldikss/vim-floaterm",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		config = function()
			vim.keymap.set({ "i", "n" }, "<C-Q>", "<CMD>NvimTreeOpen<CR>", { silent = true })
			vim.keymap.set({ "n" }, "<F1>", ":FloatermToggle<CR>", { silent = true })
			vim.keymap.set({ "t" }, "<F1>", [[<C-\><C-n>:FloatermToggle<CR>]], { silent = true })
			vim.keymap.set({ "n" }, "<F2>", ":FloatermNew<CR>", { silent = true })
			vim.keymap.set({ "t" }, "<F2>", [[<C-\><C-n>:FloatermNew<CR>]], { silent = true })
			vim.keymap.set({ "n" }, "<F3>", ":FloatermPrev<CR>", { silent = true })
			vim.keymap.set({ "t" }, "<F3>", [[<C-\><C-n>:FloatermPrev<CR>]], { silent = true })
			vim.keymap.set({ "n" }, "<F4>", ":FloatermNext<CR>", { silent = true })
			vim.keymap.set({ "t" }, "<F4>", [[<C-\><C-n>:FloatermNext<CR>]], { silent = true })
			vim.g.floaterm_width = 0.85
			vim.g.floaterm_height = 0.85
			vim.g.floaterm_autoclose = 2
			vim.g.floaterm_title = "Terminal: $1/$2"
			vim.g.floaterm_titleposition = 2
		end,
	},
	-- { 'akinsho/toggleterm.nvim', version = "*", config = true }
}
