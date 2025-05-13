return {
	{
		-- A pretty preview window for Neovim that provides VSCode-like peek preview functionality for LSP locations. Glance enables you to preview, navigate, and edit LSP-provided code locations without leaving your current context.
		"dnlhc/glance.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		cmd = "Glance",
		keys = {
			{ "gd", "<CMD>Glance definitions<CR>" },
			{ "gr", "<CMD>Glance references<CR>" },
			{ "gy", "<CMD>Glance type_definitions<CR>" },
			{ "gm", "<CMD>Glance implementations<CR>" },
		},
	},
	{
		-- Neovim plugin for automatically highlighting other uses of the word under the cursor using either LSP, Tree-sitter, or regex matching.
		"RRethy/vim-illuminate",
	},
}
