-- Servers configured under after/lsp/<name>.lua and enabled here, each with
-- the Mason package that installs it on a machine without the lsp bundle.
-- `:checkhealth vim.lsp` lists them and flags any whose binary is missing.
local servers = {
	ruff = "ruff",
	ty = "ty",
	lua_ls = "lua-language-server",
	bashls = "bash-language-server",
	marksman = "marksman",
	-- texlab = "texlab",
	cmake = "cmake-language-server",
	dockerls = "dockerfile-language-server",
	yamlls = "yaml-language-server",
	jsonls = "json-lsp",
	taplo = "taplo",
}

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
		config = function()
			-- vim.lsp.enable() skips a server whose binary is missing without a
			-- word, so say so once per session, when a file that wants it opens.
			local hinted = {}
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup(
					"user.lsp_missing_hint",
					{ clear = true }
				),
				callback = function(args)
					local ft = vim.bo[args.buf].filetype
					for name, mason in pairs(servers) do
						local config = not hinted[name] and vim.lsp.config[name]
						local bin = config and type(config.cmd) == "table" and config.cmd[1]
						if
							bin
							and vim.list_contains(config.filetypes or {}, ft)
							and vim.fn.executable(bin) == 0
						then
							hinted[name] = true
							vim.notify(
								("%s not found on PATH — install it externally or run :MasonInstall %s"):format(
									bin,
									mason
								),
								vim.log.levels.WARN
							)
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
					map("grt", function()
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

			vim.lsp.enable(vim.tbl_keys(servers))
		end,
	},
}
