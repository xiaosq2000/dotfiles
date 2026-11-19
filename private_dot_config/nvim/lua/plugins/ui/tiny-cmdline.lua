return {
	"rachartier/tiny-cmdline.nvim",
	cond = not require("core.env").kitty_scrollback,
	dependencies = { "saghen/blink.cmp" },
	event = "VeryLazy",
	config = function()
		local tiny_cmdline = require("tiny-cmdline")
		tiny_cmdline.setup({ on_reposition = tiny_cmdline.adapters.blink })
	end,
}
