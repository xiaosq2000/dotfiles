return {
	---@type LazySpec
	{
		"mikavilpas/yazi.nvim",
		event = "VeryLazy",
		-- All three live on the -/_/= key cluster so the file manager reads as one
		-- plugin instead of being scattered across unrelated prefixes.
		keys = {
			{
				"<localleader>-",
				"<cmd>Yazi<cr>",
				desc = "Yazi at the current file",
			},
			{
				-- Open in the current working directory
				"<localleader>_",
				"<cmd>Yazi cwd<cr>",
				desc = "Yazi in nvim's working directory",
			},
			{
				-- NOTE: this requires a version of yazi that includes
				-- https://github.com/sxyazi/yazi/pull/1305 from 2024-07-18
				"<localleader>=",
				"<cmd>Yazi toggle<cr>",
				desc = "Yazi resume the last session",
			},
		},
		---@type YaziConfig
		opts = {
			open_for_directories = true,
			integrations = {
				grep_in_directory = "fzf-lua",
			},
			keymaps = {
				show_help = "<f1>",
			},
		},
	},
}
