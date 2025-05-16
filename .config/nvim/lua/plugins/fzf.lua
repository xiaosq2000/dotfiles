return {
	"ibhagwan/fzf-lua",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	-- dependencies = { "echasnovski/mini.icons" },
	opts = {
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
			"<space>ff",
			function()
				require("fzf-lua").files()
			end,
			desc = "Files",
		},
		{
			"<space>fg",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "Grep",
		},
		{
			"<space>fb",
			function()
				require("fzf-lua").buffers()
			end,
			desc = "Buffers",
		},
		{
			"<space>fh",
			function()
				require("fzf-lua").help_tags()
			end,
			desc = "Help tags",
		},
		{
			"<space>fr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "Recent files",
		},
		{
			"<space>fm",
			function()
				require("fzf-lua").marks()
			end,
			desc = "Marks",
		},
		{
			"<space>fc",
			function()
				require("fzf-lua").commands()
			end,
			desc = "Commands",
		},
		{
			"<space>fk",
			function()
				require("fzf-lua").keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<space>ft",
			function()
				require("fzf-lua").colorschemes()
			end,
			desc = "Themes",
		},
		{
			"<space>fd",
			function()
				require("fzf-lua").grep_cword()
			end,
			desc = "Word under cursor",
		},
		{
			"<space>fp",
			function()
				require("fzf-lua").git_files()
			end,
			desc = "Git files",
		},
		{
			"<space>fs",
			function()
				require("fzf-lua").git_status()
			end,
			desc = "Git status",
		},
		{
			"<space>fl",
			function()
				require("fzf-lua").resume()
			end,
			desc = "Resume last search",
		},
		{
			"<space>fe",
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
		},
	},
	config = function()
		require("fzf-lua").setup({
			"hide",
			fzf_opts = { ["--cycle"] = true },
			keymap = {
				fzf = {
					-- use ctrl-q to select all items and convert to quickfix list
					["ctrl-q"] = "select-all+accept",
				},
			},
		})
	end,
}
