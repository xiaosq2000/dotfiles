return {
	"rmagatti/auto-session",
	lazy = false,
	enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {
		allowed_dirs = { "~/Projects/*" },
		lazy_support = true,
		-- log_level = "debug",
	},
	init = function()
		vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
	end,
}
