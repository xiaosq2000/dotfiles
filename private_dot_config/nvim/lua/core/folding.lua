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
--- Append `s` to `result` as virtual text chunks, split wherever the treesitter
--- highlight group changes so the folded line keeps its syntax colours.
--- ref: https://www.reddit.com/r/neovim/comments/1fzn1zt/custom_fold_text_function_with_treesitter_syntax
local function fold_virt_text(result, s, lnum, coloff)
	coloff = coloff or 0
	local text = ""
	local hl
	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local capture = hls[#hls]
		if capture then
			local new_hl = "@" .. capture.capture
			if new_hl ~= hl then
				table.insert(result, { text, hl })
				text = ""
			end
			text = text .. char
			hl = new_hl
		else
			text = text .. char
		end
	end
	table.insert(result, { text, hl })
end

--- Render a fold as `<first line> ... <last line>`.
--- Global because 'foldtext' can only reference a Vimscript-visible function.
function _G.custom_foldtext()
	local start =
		vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.o.tabstop))
	local end_str = vim.fn.getline(vim.v.foldend)
	local result = {}
	fold_virt_text(result, start, vim.v.foldstart - 1)
	table.insert(result, { " ... ", "Delimiter" })
	fold_virt_text(
		result,
		vim.trim(end_str),
		vim.v.foldend - 1,
		#(end_str:match("^(%s+)") or "")
	)
	return result
end

vim.o.foldtext = "v:lua.custom_foldtext()"
