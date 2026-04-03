-- parser engine
return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	lazy = false,
	branch = "main",
	config = function()
		local parsers = require("nvim-treesitter.parsers")
		local ts_indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		local group = vim.api.nvim_create_augroup("nvim-treesitter-start", { clear = true })

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
				if not lang then
					return
				end

				local parser = parsers[lang]
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
	end,
}
