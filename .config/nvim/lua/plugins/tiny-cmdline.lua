return {
	"rachartier/tiny-cmdline.nvim",
	event = "VeryLazy",
	config = function()
		require("tiny-cmdline").setup({
			on_reposition = require("tiny-cmdline").adapters.blink,
		})
	end,
}
