return {
	"rose-pine/neovim",
	name = "rose-pine",
	lazy = false,
	priority = 1000,
	config = function()
		-- variants: rose-pine (main), rose-pine-moon, rose-pine-dawn
		vim.cmd.colorscheme("rose-pine-dawn")
	end,
}
