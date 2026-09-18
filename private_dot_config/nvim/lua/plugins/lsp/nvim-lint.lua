return {
	"mfussenegger/nvim-lint",
	cond = not require("core.env").kitty_scrollback,
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			gitcommit = { "codespell" },
			markdown = { "codespell" },
			tex = { "codespell" },
			text = { "codespell" },
		}

		local warned = false

		local generation = {}
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = vim.api.nvim_create_augroup("user.lint", { clear = true }),
			callback = function(args)
				if vim.bo[args.buf].buftype ~= "" then
					return
				end
				if not lint.linters_by_ft[vim.bo[args.buf].filetype] then
					return
				end

				if vim.fn.executable("codespell") == 0 then
					if not warned then
						warned = true
						vim.notify(
							"codespell not found — :MasonInstall codespell",
							vim.log.levels.WARN
						)
					end
					return
				end

				generation[args.buf] = (generation[args.buf] or 0) + 1
				local current = generation[args.buf]
				vim.defer_fn(function()
					if
						generation[args.buf] ~= current
						or not vim.api.nvim_buf_is_valid(args.buf)
					then
						return
					end
					vim.api.nvim_buf_call(args.buf, lint.try_lint)
				end, 100)
			end,
			desc = "Run linters for the current filetype",
		})
	end,
}
