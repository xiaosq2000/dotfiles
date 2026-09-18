-- snippet engine
return {
	{
		"L3MON4D3/LuaSnip",
		version = "v2.*",
		build = "make install_jsregexp",
		config = function()
			local ls = require("luasnip")
			local snippet_path = vim.fn.stdpath("config") .. "/lua/LuaSnip"

			ls.config.setup({
				-- Modern equivalents of the deprecated `history = true` behavior.
				keep_roots = true,
				link_roots = true,
				link_children = true,
				exit_roots = false,
				enable_autosnippets = true,
				cut_selection_keys = "<C-F>",
			})

			vim.keymap.set({ "i" }, "<C-F>", function()
				ls.expand_or_jump()
			end, { silent = true })
			vim.keymap.set({ "s" }, "<C-F>", function()
				ls.jump(1)
			end, { silent = true })
			vim.keymap.set({ "i", "s" }, "<C-B>", function()
				ls.jump(-1)
			end, { silent = true })
			vim.keymap.set({ "i", "s" }, "<C-E>", function()
				if ls.choice_active() then
					ls.change_choice(1)
				end
			end, { silent = true })

			require("luasnip.loaders.from_vscode").lazy_load()
			require("luasnip.loaders.from_lua").lazy_load({
				paths = snippet_path,
			})

			-- Saving a snippet file is the reload signal; no keystroke needed.
			vim.api.nvim_create_autocmd("BufWritePost", {
				group = vim.api.nvim_create_augroup("user.luasnip", { clear = true }),
				-- Snippets live one directory down (LuaSnip/tex/basics.lua), so the
				-- ** is load-bearing; a plain /*.lua pattern would never fire.
				pattern = snippet_path .. "/**/*.lua",
				callback = function()
					require("luasnip.loaders.from_lua").load({
						paths = snippet_path,
					})
				end,
				desc = "Reload Lua snippets on write",
			})

			vim.keymap.set("n", "<leader>es", function()
				vim.cmd.vsplit(vim.fn.fnameescape(snippet_path .. "/tex"))
			end, { desc = "Edit TeX snippets" })
		end,
	},
}
