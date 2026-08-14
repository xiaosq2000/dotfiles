-- Servers configured under after/lsp/<name>.lua and enabled here. Executable
-- and Mason package names are explicit because neither necessarily matches the
-- nvim-lspconfig config name.
local servers = {
	{ name = "ruff", executables = { "ruff" }, mason = "ruff" },
	{ name = "ty", executables = { "ty" }, mason = "ty" },
	{
		name = "lua_ls",
		executables = { "lua-language-server" },
		mason = "lua-language-server",
	},
	{
		name = "bashls",
		executables = { "bash-language-server" },
		mason = "bash-language-server",
	},
	{ name = "marksman", executables = { "marksman" }, mason = "marksman" },
	-- "texlab",
	{
		name = "cmake",
		executables = { "cmake-language-server" },
		mason = "cmake-language-server",
	},
	{
		name = "dockerls",
		executables = { "docker-langserver" },
		mason = "dockerfile-language-server",
	},
	{
		name = "docker_compose_language_service",
		executables = { "docker-compose-langserver" },
		mason = "docker-compose-language-service",
	},
	{
		name = "yamlls",
		executables = { "yaml-language-server" },
		mason = "yaml-language-server",
	},
	{
		name = "jsonls",
		executables = { "vscode-json-language-server" },
		mason = "json-lsp",
	},
	{ name = "taplo", executables = { "taplo" }, mason = "taplo" },
}

local function executable_path(server)
	for _, executable in ipairs(server.executables) do
		local path = vim.fn.exepath(executable)
		if path ~= "" then
			return path
		end
	end
end

-- `cond`, not `enabled`: these are installed and managed as usual, just not
-- loaded when nvim is standing in as kitty's scrollback pager.
local cond = not require("core.env").kitty_scrollback

return {
	{
		"mason-org/mason.nvim",
		cond = cond,
		-- Not lazy-loaded: setup() is what puts mason's bin directory on PATH,
		-- and the servers enabled below are resolved from it.
		lazy = false,
		opts = {},
	},
	{
		"neovim/nvim-lspconfig",
		cond = cond,
		lazy = false,
		dependencies = { "mason-org/mason.nvim" },
		keys = {
			{
				"<leader>qd",
				vim.diagnostic.setloclist,
				desc = "Diagnostics to location list",
			},
			{ "<leader>qo", "<cmd>copen<cr>", desc = "Open quickfix window" },
			{ "<leader>qc", "<cmd>cclose<cr>", desc = "Close quickfix window" },
		},
		config = function()
			vim.api.nvim_create_user_command("LspEnabled", function()
				local lines = {}
				for _, server in ipairs(servers) do
					local config = vim.lsp.config[server.name]
					local fts = config and config.filetypes or {}
					local executable = executable_path(server)
					local status = executable
						or ("missing; :MasonInstall %s"):format(server.mason)
					lines[#lines + 1] = ("%s [%s]\n  filetypes: %s"):format(
						server.name,
						status,
						table.concat(fts, ", ")
					)
				end
				vim.notify(
					table.concat(lines, "\n"),
					vim.log.levels.INFO,
					{ title = "Enabled LSPs" }
				)
			end, { desc = "List explicitly enabled LSP servers" })

			-- Hint once per session when a configured server's binary is missing.
			local hinted = {}
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup(
					"user.lsp_missing_hint",
					{ clear = true }
				),
				callback = function(args)
					local ft = vim.bo[args.buf].filetype
					for _, server in ipairs(servers) do
						local config = not hinted[server.name]
								and vim.lsp.config[server.name]
							or nil
						if config and vim.list_contains(config.filetypes or {}, ft) then
							if executable_path(server) == nil then
								hinted[server.name] = true
								vim.notify(
									("%s not found on PATH — install it externally or run :MasonInstall %s"):format(
										server.executables[1],
										server.mason
									),
									vim.log.levels.WARN
								)
							end
						end
					end
				end,
				desc = "Warn about missing LSP binaries",
			})

			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup(
					"user.lsp_attach",
					{ clear = true }
				),
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					if client == nil then
						return
					end

					if client.name == "ruff" then
						-- Prefer Ty for hover and keep Ruff focused on diagnostics/actions.
						client.server_capabilities.hoverProvider = false
					end

					if client:supports_method("textDocument/documentHighlight") then
						local highlight_group = vim.api.nvim_create_augroup(
							("user.lsp_highlight.%d"):format(args.buf),
							{ clear = true }
						)
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							group = highlight_group,
							buffer = args.buf,
							callback = vim.lsp.buf.document_highlight,
							desc = "LSP: highlight references under cursor",
						})
						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							group = highlight_group,
							buffer = args.buf,
							callback = vim.lsp.buf.clear_references,
							desc = "LSP: clear reference highlights",
						})
					end

					local function map(lhs, rhs, desc)
						vim.keymap.set(
							"n",
							lhs,
							rhs,
							{ buffer = args.buf, silent = true, desc = desc }
						)
					end

					-- Keep the built-in gr* key family, with fzf-lua providing a
					-- consistent multi-result view.
					map("grd", function()
						require("fzf-lua").lsp_definitions()
					end, "LSP definitions")
					map("grr", function()
						require("fzf-lua").lsp_references()
					end, "LSP references")
					map("gry", function()
						require("fzf-lua").lsp_typedefs()
					end, "LSP type definitions")
					map("gri", function()
						require("fzf-lua").lsp_implementations()
					end, "LSP implementations")
					map("grk", vim.lsp.buf.signature_help, "LSP signature help")
					map("grD", function()
						require("fzf-lua").lsp_declarations()
					end, "LSP declarations")

					map(
						"<leader>wa",
						vim.lsp.buf.add_workspace_folder,
						"Workspace add folder"
					)
					map(
						"<leader>wr",
						vim.lsp.buf.remove_workspace_folder,
						"Workspace remove folder"
					)
					map("<leader>wl", function()
						vim.notify(
							vim.inspect(vim.lsp.buf.list_workspace_folders()),
							vim.log.levels.INFO,
							{
								title = "Workspace folders",
							}
						)
					end, "Workspace list folders")

					map("<leader>li", function()
						local names = {}
						for _, attached in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
							names[#names + 1] = attached.name
						end
						vim.notify(
							#names > 0 and table.concat(names, ", ")
								or "No LSP clients attached",
							vim.log.levels.INFO,
							{
								title = ("LSP clients for %s"):format(
									vim.bo[args.buf].filetype
								),
							}
						)
					end, "LSP clients")
				end,
				desc = "LSP: buffer-local keymaps",
			})

			for _, server in ipairs(servers) do
				vim.lsp.enable(server.name)
			end
		end,
	},
}
