-- LaTex
return {
	"lervag/vimtex",
	lazy = false,
	init = function()
		vim.g.tex_flavor = "latex"
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
				"-pdflatex=lualatex",
				"-shell-escape",
				"-verbose",
				"-file-line-error",
				"-synctex=1",
				"-interaction=nonstopmode",
			},
		}
		vim.g.vimtex_parser_bib_backend = "bibtex"
		vim.g.vimtex_quickfix_mode = 0
		-- vim.g.vimtex_format_enabled = 1
		-- vim.g.vimtex_complete_close_braces = 1
		-- Keymaps
		-- TODO: use luasnip instead
		-- vim.keymap.set("i", "<A-i>", "\\item ", { buffer = false })
	end,
}
