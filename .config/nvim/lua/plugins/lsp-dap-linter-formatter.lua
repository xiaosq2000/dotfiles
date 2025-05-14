return {
	{
		-- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
		"williamboman/mason.nvim",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		config = function()
			require("mason").setup()
		end,
	},
	{
		-- a bridge between nvim-lspconfig and mason.
		"williamboman/mason-lspconfig.nvim",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				automatic_installation = true,
				ensure_installed = {
					"ruff",
					"pyright",
					"clangd",
					"lua_ls",
					"bashls",
					"marksman",
					"cmake",
					"dockerls",
					"docker_compose_language_service",
					"jsonls",
					"taplo",
					-- "texlab", # BUG: w/ vimtex
				},
			})
		end,
	},
	{
		"neovim/nvim-lspconfig",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		dependencies = { "DNLHC/glance.nvim" },
		config = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("lsp_attach_disable_ruff_hover", { clear = true }),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client == nil then
						return
					end
					if client.name == "ruff" then
						-- Disable hover in favor of Pyright
						client.server_capabilities.hoverProvider = false
					end
				end,
				desc = "LSP: Disable hover capability from Ruff",
			})
			vim.lsp.config("pyright", {
				settings = {
					pyright = {
						-- Using Ruff's import organizer
						disableOrganizeImports = true,
					},
					python = {
						analysis = {
							-- Ignore all files for analysis to exclusively use Ruff for linting
							ignore = { "*" },
						},
					},
				},
			})
			-- Use LspAttach autocommand to only map the following keys
			-- after the language server attaches to the current buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function()
					require("which-key").add({
						{ "K", vim.lsp.buf.hover },
						{ "grd", "<CMD>Glance definitions<CR>", desc = "vim.lsp.buf.definitions()" },
						{ "grr", "<CMD>Glance references<CR>", desc = "vim.lsp.buf.references()" },
						{ "gry", "<CMD>Glance type_definitions<CR>", desc = "vim.lsp.buf.type_definitions()" },
						{ "gri", "<CMD>Glance implementations<CR>", desc = "vim.lsp.buf.implementations()" },
						{ "grk", vim.lsp.buf.signature_help, desc = "vim.lsp.buf.signature_help" },
						{ "grD", vim.lsp.buf.declaration, desc = "vim.lsp.buf.declaration" },
						{
							"<leader>wa",
							vim.lsp.buf.add_workspace_folder,
							desc = "vim.lsp.buf.add_workspace_folder",
						},
						{
							"<leader>wr",
							vim.lsp.buf.remove_workspace_folder,
							desc = "vim.lsp.buf.remove_workspace_folder",
						},
						{
							"<leader>wl",
							function()
								print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
							end,
						},
					})
				end,
			})
		end,
		keys = {
			{
				"<space>q",
				vim.diagnostic.setloclist,
				desc = "Set diagnostics in location list",
			},
			{
				"<space>e",
				vim.diagnostic.open_float,
				desc = "Open floating diagnostic window",
			},
			{
				"<space>co",
				":copen<CR>",
				desc = "Open quickfix window",
			},
			{
				"<space>cx",
				":cclose<CR>",
				desc = "Close quickfix window",
			},
		},
	},
	{
		-- A pretty preview window for Neovim that provides VSCode-like peek preview functionality for LSP locations. Glance enables you to preview, navigate, and edit LSP-provided code locations without leaving your current context.
		"dnlhc/glance.nvim",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		cmd = "Glance",
	},
	{
		"stevearc/conform.nvim",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		dependencies = { "williamboman/mason.nvim", "folke/which-key.nvim" },
		config = function()
			require("conform").setup({
				formatters_by_ft = {
					lua = { "stylua" },
					python = {
						-- To fix auto-fixable lint errors.
						"ruff_fix",
						-- To run the Ruff formatter.
						"ruff_format",
						-- To organize the imports.
						"ruff_organize_imports",
					},
					cpp = { "clang-format" },
					c = { "clang-format" },
					sh = { "beautysh" },
					toml = { "taplo" },
					tex = { "latexindent" },
				},
			})
			require("which-key").add({
				"<space>f",
				function()
					require("conform").format({
						lsp_fallback = true,
						async = true,
						timeout_ms = 1000,
					})
				end,
			})
		end,
	},
	{
		"zapling/mason-conform.nvim",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		dependencies = { "stevearc/conform.nvim", "williamboman/mason.nvim" },
	},
	{
		"mfussenegger/nvim-lint",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		config = function()
			require("lint").linters_by_ft = {
				python = { "ruff", "mypy" },
				c = { "cpplint", "clang-tidy" },
			}
		end,
	},
	{
		"mfussenegger/nvim-dap",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
	},
	{
		"mfussenegger/nvim-dap-python",
		enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true",
		dependencies = { "mfussenegger/nvim-dap" },
	},
}
