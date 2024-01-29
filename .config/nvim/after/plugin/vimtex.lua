vim.g.tex_flavor = "latex"
vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_compiler_latexmk = {
    ['aux_dir'] = '',
    ['out_dir'] = '',
    ['callback'] = 1,
    ['continuous'] = 1,
    ['executable'] = 'latexmk',
    ['hooks'] = '',
    ['options'] = {
        '-pdflatex=xelatex', -- use xelatex engine
        '-verbose',
        '-file-line-error',
        '-synctex=1',
        '-interaction=nonstopmode',
    },
}
vim.g.vimtex_parser_bib_backend = 'bibtex'
vim.g.vimtex_quickfix_mode = 0
