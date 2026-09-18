return {
	"rachartier/tiny-cmdline.nvim",
	dependencies = { "saghen/blink.cmp" },
	event = "VeryLazy",
	config = function()
		local tiny_cmdline = require("tiny-cmdline")
		tiny_cmdline.setup({ on_reposition = tiny_cmdline.adapters.blink })
	end,
}
