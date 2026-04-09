return {
	"rachartier/tiny-cmdline.nvim",
	event = "VeryLazy",
	config = function()
		vim.o.cmdheight = 0
		require("tiny-cmdline").setup({
			on_reposition = require("tiny-cmdline").adapters.blink,
		})
	end,
}
