-- prettierd is a daemon and takes no prettier CLI flags, so our defaults
-- live in a config file it falls back to when a project ships none of its own.
local prettierd_config = vim.fn.stdpath("config") .. "/prettierd.json"

return {
	"stevearc/conform.nvim",
	cond = not require("core.env").kitty_scrollback,
	event = "BufWritePre",
	cmd = "ConformInfo",
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({ async = true, timeout_ms = 1000 })
			end,
			mode = { "n", "v" },
			desc = "Format buffer",
		},
	},
	init = function()
		vim.api.nvim_create_user_command(
			"FormatDisable",
			function(args)
				if args.bang then
					vim.b.disable_autoformat = true
					vim.notify("Format on save disabled for this buffer")
				else
					vim.g.disable_autoformat = true
					vim.notify("Format on save disabled globally")
				end
			end,
			{ bang = true, desc = "Disable format on save (! for current buffer)" }
		)

		vim.api.nvim_create_user_command("FormatEnable", function(args)
			if args.bang then
				vim.b.disable_autoformat = false
				vim.notify("Format on save enabled for this buffer")
			else
				vim.g.disable_autoformat = false
				vim.notify("Format on save enabled globally")
			end
		end, { bang = true, desc = "Enable format on save (! for current buffer)" })
	end,
	opts = {
		default_format_opts = {
			lsp_format = "fallback",
		},
		format_on_save = function(bufnr)
			if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
				return
			end
			return { timeout_ms = 1000, lsp_format = "fallback" }
		end,
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "ruff_organize_imports", "ruff_fix", "ruff_format" },
			cpp = { "clang-format" },
			c = { "clang-format" },
			bash = { "shfmt" },
			sh = { "shfmt" },
			zsh = { "shfmt" },
			-- What `prettier --support-info` reports, minus the ids without a
			-- neovim filetype. Unlisted filetypes stay on the LSP fallback.
			markdown = { "prettierd", lsp_format = "never" },
			css = { "prettierd" },
			graphql = { "prettierd" },
			handlebars = { "prettierd" },
			html = { "prettierd" },
			javascript = { "prettierd" },
			javascriptreact = { "prettierd" },
			json = { "prettierd" },
			json5 = { "prettierd" },
			jsonc = { "prettierd" },
			less = { "prettierd" },
			mdx = { "prettierd" },
			scss = { "prettierd" },
			typescript = { "prettierd" },
			typescriptreact = { "prettierd" },
			vue = { "prettierd" },
			yaml = { "prettierd" },
			toml = { "taplo" },
			tex = { "tex-fmt" },
		},
		formatters = {
			prettierd = {
				env = { PRETTIERD_DEFAULT_CONFIG = prettierd_config },
			},
		},
	},
}
