-- parser engine
local ensure_installed = {
	"bash",
	"c",
	"cmake",
	"cpp",
	"dockerfile",
	"git_config",
	"git_rebase",
	"gitcommit",
	"gitignore",
	"html",
	"jinja",
	"jinja_inline",
	"json",
	"lua",
	"markdown",
	"markdown_inline",
	"python",
	"toml",
	"yaml",
}

-- Languages that must never get a tree-sitter session, even if the parser is
-- installed as a dependency of another one. `latex` is handled by vimtex, whose
-- syntax, indent and folding clash with tree-sitter's.
local disabled = {
	latex = true,
}

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	lazy = false,
	branch = "main",
	config = function()
		local treesitter = require("nvim-treesitter")
		local parser_configs = require("nvim-treesitter.parsers")
		local ts_indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		local group =
			vim.api.nvim_create_augroup("nvim-treesitter-start", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			pattern = "*",
			callback = function(args)
				if vim.bo[args.buf].buftype ~= "" then
					return
				end

				local filetype = vim.bo[args.buf].filetype
				if filetype == "" then
					return
				end

				local lang = vim.treesitter.language.get_lang(filetype)
				if not lang or disabled[lang] then
					return
				end

				local parser = parser_configs[lang]
				if not vim.treesitter.language.add(lang) then
					if parser and parser.tier ~= 4 then
						vim.notify_once(
							("Tree-sitter parser '%s' is available for '%s'. Run :TSInstall %s"):format(
								lang,
								filetype,
								lang
							),
							vim.log.levels.INFO,
							{ title = "nvim-treesitter" }
						)
					end
					return
				end

				vim.treesitter.stop(args.buf)
				vim.treesitter.start(args.buf, lang)

				if vim.treesitter.query.get(lang, "indents") then
					vim.bo[args.buf].indentexpr = ts_indentexpr
				elseif vim.bo[args.buf].indentexpr == ts_indentexpr then
					vim.bo[args.buf].indentexpr = ""
				end
			end,
		})

		treesitter.install(ensure_installed)
	end,
}
