return {
	"ibhagwan/fzf-lua",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	-- dependencies = { "echasnovski/mini.icons" },
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
				-- fzf-lua is very fast, but it really struggled to preview a couple files
				-- in a repo. Those files were very big JavaScript files (1MB, minified, all on a single line).
				-- It turns out it was Treesitter having trouble parsing the files.
				-- With this change, the previewer will not add syntax highlighting to files larger than 100KB
				-- (Yes, I know you shouldn't have 100KB minified files in source control.)
				syntax_limit_b = 1024 * 100, -- 100KB
			},
		},
	},
	keys = {
		-- Use the new which-key spec format for lazy loading
		{
			"<leader>sf",
			function()
				require("fzf-lua").files()
			end,
			desc = "Files",
		},
		{
			"<leader>sg",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>sb",
			function()
				require("fzf-lua").buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>sh",
			function()
				require("fzf-lua").help_tags()
			end,
			desc = "Help tags",
		},
		{
			"<leader>sr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "Recent files",
		},
		{
			"<leader>sm",
			function()
				require("fzf-lua").marks()
			end,
			desc = "Marks",
		},
		{
			"<leader>sc",
			function()
				require("fzf-lua").commands()
			end,
			desc = "Commands",
		},
		{
			"<leader>sk",
			function()
				require("fzf-lua").keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<leader>st",
			function()
				require("fzf-lua").colorschemes()
			end,
			desc = "Themes",
		},
		{
			"<leader>sd",
			function()
				require("fzf-lua").grep_cword()
			end,
			desc = "Word under cursor",
		},
		{
			"<leader>sp",
			function()
				require("fzf-lua").git_files()
			end,
			desc = "Git files",
		},
		{
			"<leader>ss",
			function()
				require("fzf-lua").git_status()
			end,
			desc = "Git status",
		},
		{
			"<leader>sl",
			function()
				require("fzf-lua").resume()
			end,
			desc = "Resume last search",
		},
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
