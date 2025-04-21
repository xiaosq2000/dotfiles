return {
	{
		"rose-pine/neovim",
		name = "rose-pine",
		config = function()
			-- main, moon, dawn
			vim.cmd.colorscheme("rose-pine-main")
		end,
	},
	{
		"catppuccin/nvim",
		name = "catppuccin",
		enabled = false,
		-- config = function()
		--     -- latte, frappe, macchiato, mocha
		--     vim.cmd.colorscheme "catppuccin-latte"
		-- end
	},
}
