local enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true"

local lsp_servers = {
	"ruff",
	"ty",
	"lua_ls",
	"bashls",
	"marksman",
	"texlab",
	"cmake",
	"dockerls",
	"docker_compose_language_service",
	"yamlls",
	"jsonls",
	"taplo",
}

return {
	{
		"mason-org/mason.nvim",
		enabled = enabled,
		opts = {},
	},
	{
		"neovim/nvim-lspconfig",
		lazy = false,
		enabled = enabled,
		dependencies = { "dnlhc/glance.nvim" },
		config = function()
			vim.api.nvim_create_user_command("LspEnabled", function()
				local lines = {}
				for _, name in ipairs(lsp_servers) do
					local config = vim.lsp.config[name]
					local fts = config and config.filetypes or {}
					lines[#lines + 1] = ("%s => %s"):format(name, table.concat(fts, ", "))
				end
				vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Enabled LSPs" })
			end, { desc = "List explicitly enabled LSP servers" })

			-- Hint once per session when an LSP binary is missing
			local hinted = {}
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("LspMissingHint", { clear = true }),
				callback = function(args)
					local ft = vim.bo[args.buf].filetype
					for _, name in ipairs(lsp_servers) do
						if hinted[name] then
							goto continue
						end
						local config = vim.lsp.config[name]
						if not config then
							goto continue
						end
					if not vim.list_contains(config.filetypes or {}, ft) then
						goto continue
					end
					local cmd = config.cmd
					local executable = type(cmd) == "table" and cmd[1] or type(cmd) == "string" and cmd or nil
					if executable and vim.fn.executable(executable) == 0 then
						hinted[name] = true
						vim.notify(("%s not found — :MasonInstall %s"):format(name, name), vim.log.levels.WARN)
					end
						::continue::
					end
				end,
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client == nil then
						return
					end

					if client.name == "ruff" then
						-- Prefer Ty for hover and keep Ruff focused on diagnostics/actions.
						client.server_capabilities.hoverProvider = false
					end

					local function map(lhs, rhs, desc)
						vim.keymap.set("n", lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
					end

					-- Glance overrides for built-in gr* mappings
					map("grd", "<cmd>Glance definitions<cr>", "LSP definitions")
					map("grr", "<cmd>Glance references<cr>", "LSP references")
					map("gry", "<cmd>Glance type_definitions<cr>", "LSP type definitions")
					map("gri", "<cmd>Glance implementations<cr>", "LSP implementations")
					map("grk", vim.lsp.buf.signature_help, "LSP signature help")
					map("grD", vim.lsp.buf.declaration, "LSP declaration")
					map("<leader>wa", vim.lsp.buf.add_workspace_folder, "Workspace add")
					map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Workspace remove")
					map("<leader>wl", function()
						print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
					end, "Workspace list")
					map("<leader>li", function()
						local names = {}
						for _, attached_client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
							names[#names + 1] = attached_client.name
						end

						local message = #names > 0 and table.concat(names, ", ") or "No LSP clients attached"
						vim.notify(message, vim.log.levels.INFO, {
							title = ("LSP clients for %s"):format(vim.bo[args.buf].filetype),
						})
					end, "LSP clients")
				end,
				desc = "LSP: buffer-local keymaps",
			})

			for _, name in ipairs(lsp_servers) do
				vim.lsp.enable(name)
			end
		end,
		keys = {
			{
				"<space>q",
				vim.diagnostic.setloclist,
				desc = "Set diagnostics in location list",
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
		"dnlhc/glance.nvim",
		enabled = enabled,
		cmd = "Glance",
	},
	{
		"stevearc/conform.nvim",
		enabled = enabled,
		dependencies = { "mason-org/mason.nvim" },
		opts = {
			default_format_opts = {
				lsp_format = "fallback",
			},
			formatters_by_ft = {
				lua = { "stylua" },
				python = {
					"ruff_organize_imports",
					"ruff_fix",
					"ruff_format",
				},
				cpp = { "clang-format" },
				c = { "clang-format" },
				bash = { "shfmt" },
				sh = { "shfmt" },
				zsh = { "shfmt" },
				json = { "prettier" },
				jsonc = { "prettier" },
				toml = { "taplo" },
				tex = { "tex-fmt" },
			},
		},
		keys = {
			{
				"<space>f",
				function()
					require("conform").format({
						async = true,
						timeout_ms = 1000,
					})
				end,
				desc = "Format buffer",
			},
		},
	},
}
