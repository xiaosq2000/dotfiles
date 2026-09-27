vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldcolumn = "0"

-- Default to treesitter folding, upgrading to LSP folding per-window when the
-- attached client can provide ranges.
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("user.lsp_folding", { clear = true }),
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client and client:supports_method("textDocument/foldingRange") then
			vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
			vim.wo.foldmethod = "expr"
		end
	end,
	desc = "Prefer LSP folding over treesitter when supported",
})

--------------------------------------------------------------------------------
---------------------------------- fold text -----------------------------------
--------------------------------------------------------------------------------
-- Empty draws a fold as its first line with that line's own highlighting.
vim.o.foldtext = ""
