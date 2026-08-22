-- LaTex
return {
	"lervag/vimtex",
	lazy = false,
	init = function()
		vim.g.tex_flavor = "latex"
		vim.g.vimtex_syntax_conceal_disable = 1
		vim.g.vimtex_view_method = "zathura"
		vim.g.vimtex_compiler_method = "latexmk"
		vim.g.vimtex_compiler_latexmk = {
			["aux_dir"] = "",
			["out_dir"] = "",
			["callback"] = 1,
			["continuous"] = 1,
			["executable"] = "latexmk",
			["hooks"] = "",
			["options"] = {
				-- "-pdflatex=lualatex",
				"-shell-escape",
				"-verbose",
				"-file-line-error",
				"-synctex=1",
				"-interaction=nonstopmode",
			},
		}
		vim.g.vimtex_parser_bib_backend = "bibtex"
		vim.g.vimtex_quickfix_mode = 0
		-- Tree-sitter is disabled for latex (see plugins/lsp/treesitter.lua), so
		-- the global treesitter 'foldexpr' yields nothing here. Use vimtex's own
		-- folder instead.
		vim.g.vimtex_fold_enabled = 1
		-- vim.g.vimtex_format_enabled = 1
		-- vim.g.vimtex_complete_close_braces = 1
		-- TODO: use luasnip instead
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("user.vimtex", { clear = true }),
			pattern = { "tex", "plaintex", "latex" },
			callback = function(args)
				vim.keymap.set("i", "<A-i>", "\\item ", {
					buffer = args.buf,
					silent = true,
					desc = "Insert \\item",
				})
			end,
			desc = "TeX-local <A-i> for \\item",
		})
	end,
}
