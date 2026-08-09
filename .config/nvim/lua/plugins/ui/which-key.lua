return {
	"folke/which-key.nvim",
	cond = not require("core.env").kitty_scrollback,
	event = "VeryLazy",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		spec = {
			{ "<leader>c", group = "code / comment / quickfix" },
			{ "<leader>e", group = "edit config" },
			{ "<leader>l", group = "lsp" },
			{ "<leader>s", group = "search (fzf-lua)" },
			{ "<leader>w", group = "workspace folders" },
			{ "<leader>y", group = "yank path" },
			{ "<localleader>l", group = "vimtex", mode = { "n", "v" } },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer-local keymaps",
		},
	},
}
