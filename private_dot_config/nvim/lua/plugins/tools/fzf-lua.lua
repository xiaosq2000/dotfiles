return {
	"ibhagwan/fzf-lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = "FzfLua",
	opts = {
		-- hide the interface instead of aborting it
		"hide",
		ui_select = {},
		fzf_opts = { ["--cycle"] = true },
		keymap = {
			fzf = {
				-- `true` inherits fzf-lua's default binds; without it they are all replaced
				true,
				-- use ctrl-q to select all items and convert to quickfix list
				["ctrl-q"] = "select-all+accept",
			},
		},
		previewers = {
			builtin = {
				-- Treesitter stalls on large minified files, so preview those
				-- without syntax highlighting.
				syntax_limit_b = 1024 * 100,
			},
		},
	},
	keys = {
		{ "<leader>sf", "<cmd>FzfLua files<cr>", desc = "Files" },
		{ "<leader>sg", "<cmd>FzfLua live_grep<cr>", desc = "Grep" },
		{ "<leader>sb", "<cmd>FzfLua buffers<cr>", desc = "Buffers" },
		{ "<leader>sh", "<cmd>FzfLua help_tags<cr>", desc = "Help tags" },
		{ "<leader>sr", "<cmd>FzfLua oldfiles<cr>", desc = "Recent files" },
		{ "<leader>sm", "<cmd>FzfLua marks<cr>", desc = "Marks" },
		{ "<leader>sc", "<cmd>FzfLua commands<cr>", desc = "Commands" },
		{ "<leader>sk", "<cmd>FzfLua keymaps<cr>", desc = "Keymaps" },
		{ "<leader>st", "<cmd>FzfLua colorschemes<cr>", desc = "Themes" },
		{ "<leader>sd", "<cmd>FzfLua grep_cword<cr>", desc = "Word under cursor" },
		{ "<leader>sp", "<cmd>FzfLua git_files<cr>", desc = "Git files" },
		{ "<leader>ss", "<cmd>FzfLua git_status<cr>", desc = "Git status" },
		{ "<leader>sl", "<cmd>FzfLua resume<cr>", desc = "Resume last search" },
		{
			"<leader>se",
			function()
				require("fzf-lua").lsp_live_workspace_symbols({
					cwd_only = true,
					actions = {
						["ctrl-e"] = function(_, opts)
							require("fzf-lua").actions.toggle_opt(opts, "cwd_only")
						end,
					},
				})
			end,
			desc = "Workspace symbols",
		},
	},
}
