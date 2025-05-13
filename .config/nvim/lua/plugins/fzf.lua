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
	},
	config = function()
		require("fzf-lua").setup({
			"hide",
			fzf_opts = { ["--cycle"] = true },
		})
	end,
}
