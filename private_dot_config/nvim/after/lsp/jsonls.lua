return {
	-- Keep this as a table so Neovim can check executability before attempting
	-- to spawn the server. nvim-lspconfig's compatibility fallback is a
	-- function, which otherwise produces an extra spawn error when it is absent.
	cmd = { "vscode-json-language-server", "--stdio" },
}
