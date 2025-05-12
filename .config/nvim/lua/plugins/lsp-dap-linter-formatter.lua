return {
	{
		-- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		-- a bridge between nvim-lspconfig and mason.
		"williamboman/mason-lspconfig.nvim",
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
					-- "texlab", # BUG:
				},
			})
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
			require("lspconfig").pyright.setup({
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
			-- local on_attach = function(client)
			-- 	if client.name == "ruff" then
			-- 		-- Disable hover in favor of Pyright
			-- 		client.server_capabilities.hoverProvider = false
			-- 	end
			-- end
			-- require("mason-lspconfig").setup_handlers({
			-- 	-- The first entry (without a key) will be the default handler
			-- 	-- and will be called for each installed server that doesn't have
			-- 	-- a dedicated handler.
			-- 	function(server_name) -- default handler (optional)
			-- 		require("lspconfig")[server_name].setup({})
			-- 	end,
			-- 	["lua_ls"] = function()
			-- 		require("lspconfig").lua_ls.setup({
			-- 			settings = {
			-- 				Lua = {
			-- 					diagnostics = {
			-- 						globals = { "vim" },
			-- 					},
			-- 				},
			-- 			},
			-- 		})
			-- 	end,
			-- 	["ruff"] = function()
			-- 		require("lspconfig").ruff.setup({
			-- 			on_attach = on_attach,
			-- 		})
			-- 	end,
			-- 	["pyright"] = function()
			-- 		require("lspconfig").pyright.setup({
			-- 			on_attach = on_attach,
			-- 			settings = {
			-- 				pyright = {
			-- 					-- Using Ruff's import organizer
			-- 					disableOrganizeImports = true,
			-- 				},
			-- 				python = {
			-- 					analysis = {
			-- 						-- Ignore all files for analysis to exclusively use Ruff for linting
			-- 						ignore = { "*" },
			-- 					},
			-- 				},
			-- 			},
			-- 		})
			-- 	end,
			-- })
		end,
	},
	{
		"stevearc/conform.nvim",
		dependencies = { "williamboman/mason.nvim" },
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
		end,
		keys = {
			{
				"<space>f",
				function()
					require("conform").format({
						lsp_fallback = true,
						async = true,
						timeout_ms = 1000,
					})
				end,
			},
		},
	},
	{
		"zapling/mason-conform.nvim",
		dependencies = { "stevearc/conform.nvim", "williamboman/mason.nvim" },
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp", "kevinhwang91/nvim-ufo" },
		-- example using `opts` for defining servers
		opts = {
			servers = {
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = {
								globals = { "vim" }, -- Recognize vim global
							},
						},
					},
				},
			},
		},
		config = function(_, opts)
			local lspconfig = require("lspconfig")
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
			}
			for server, config in pairs(opts.servers) do
				-- passing config.capabilities to blink.cmp merges with the capabilities in your
				-- `opts[server].capabilities, if you've defined it
				config.capabilities = capabilities
				config.capabilities = require("blink.cmp").get_lsp_capabilities(config.capabilities)
				lspconfig[server].setup(config)
			end

			-- Use LspAttach autocommand to only map the following keys
			-- after the language server attaches to the current buffer
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", {}),
				callback = function()
					-- Changed variable name from opts to buffer_opts
					local wk = require("which-key")
					wk.add({
						{ "K", vim.lsp.buf.hover },
						{ "gK", vim.lsp.buf.signature_help },
						{ "gD", vim.lsp.buf.declaration },
						{ "gd", vim.lsp.buf.definition },
						{ "gY", vim.lsp.buf.type_definition },
						{ "gR", vim.lsp.buf.references },
						{ "gM", vim.lsp.buf.implementation },
						{ "<space>rn", vim.lsp.buf.rename },
						{
							"<space>f",
							function()
								vim.lsp.buf.format({ async = true })
							end,
						},
						{ "<space>wa", vim.lsp.buf.add_workspace_folder },
						{ "<space>wr", vim.lsp.buf.remove_workspace_folder },
						{
							"<space>wl",
							function()
								print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
							end,
						},
						{ "<space>ca", vim.lsp.buf.code_action, mode = { "n", "v" } },
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
				"[d",
				vim.diagnostic.goto_prev,
				desc = "Go to previous diagnostic",
			},
			{
				"]d",
				vim.diagnostic.goto_next,
				desc = "Go to next diagnostic",
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
			{
				"[q",
				":cprevious<CR>",
				desc = "Previous quickfix entry",
			},
			{
				"]q",
				":cnext<CR>",
				desc = "Next quickfix entry",
			},
		},
	},
	{
		-- A pretty preview window for Neovim that provides VSCode-like peek preview functionality for LSP locations. Glance enables you to preview, navigate, and edit LSP-provided code locations without leaving your current context.
		"dnlhc/glance.nvim",
		cmd = "Glance",
		keys = {
			{ "gd", "<CMD>Glance definitions<CR>" },
			{ "gr", "<CMD>Glance references<CR>" },
			{ "gy", "<CMD>Glance type_definitions<CR>" },
			{ "gm", "<CMD>Glance implementations<CR>" },
		},
	},
	{
		"mfussenegger/nvim-lint",
		config = function()
			require("lint").linters_by_ft = {
				python = { "ruff", "mypy" },
			}
		end,
	},
	{
		"mfussenegger/nvim-dap",
	},
	{
		"mfussenegger/nvim-dap-python",
		dependencies = { "mfussenegger/nvim-dap" },
	},
}
