return {
	"folke/which-key.nvim",
	cond = not require("core.env").kitty_scrollback,
	event = "VeryLazy",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		-- One concept per prefix. Keep this in sync when adding mappings, or they
		-- show up in which-key as bare keys with no group.
		spec = {
			{ "<leader>c", group = "code" },
			{ "<leader>e", group = "edit config" },
			{ "<leader>l", group = "lsp" },
			{ "<leader>q", group = "quickfix / lists" },
			{ "<leader>s", group = "search (fzf-lua)" },
			{ "<leader>t", group = "todos (dooing)" },
			{ "<leader>u", group = "utilities" },
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
