return {
	{
		"rcarriga/nvim-notify",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			vim.notify = require("notify")
		end,
	},
}
