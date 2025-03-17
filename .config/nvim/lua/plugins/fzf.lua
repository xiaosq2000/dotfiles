return {
	"ibhagwan/fzf-lua",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	-- dependencies = { "echasnovski/mini.icons" },
	opts = {},
	keys = {
		-- Use the new which-key spec format for lazy loading
		{
			"<leader>ff",
			function()
				require("fzf-lua").files()
			end,
			desc = "Files",
		},
		{
			"<leader>fg",
			function()
				require("fzf-lua").live_grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>fb",
			function()
				require("fzf-lua").buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>fh",
			function()
				require("fzf-lua").help_tags()
			end,
			desc = "Help tags",
		},
		{
			"<leader>fr",
			function()
				require("fzf-lua").oldfiles()
			end,
			desc = "Recent files",
		},
		{
			"<leader>fm",
			function()
				require("fzf-lua").marks()
			end,
			desc = "Marks",
		},
		{
			"<leader>fc",
			function()
				require("fzf-lua").commands()
			end,
			desc = "Commands",
		},
		{
			"<leader>fk",
			function()
				require("fzf-lua").keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<leader>ft",
			function()
				require("fzf-lua").colorschemes()
			end,
			desc = "Themes",
		},
		{
			"<leader>fd",
			function()
				require("fzf-lua").grep_cword()
			end,
			desc = "Word under cursor",
		},
		{
			"<leader>fp",
			function()
				require("fzf-lua").git_files()
			end,
			desc = "Git files",
		},
		{
			"<leader>fs",
			function()
				require("fzf-lua").git_status()
			end,
			desc = "Git status",
		},
		{
			"<leader>fl",
			function()
				require("fzf-lua").resume()
			end,
			desc = "Resume last search",
		},
	},
	config = function()
		require("fzf-lua").setup({
			"hide",
			fzf_opts = { ["--cycle"] = true },
		})
	end,
}
