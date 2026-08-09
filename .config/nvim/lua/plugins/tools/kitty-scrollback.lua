-- Nvim as kitty's scrollback pager. Plugins that would get in the way are
-- switched off via `cond` on `core.env.kitty_scrollback`.
return {
	"mikesmithgh/kitty-scrollback.nvim",
	lazy = true,
	cmd = {
		"KittyScrollbackGenerateKittens",
		"KittyScrollbackCheckHealth",
		"KittyScrollbackGenerateCommandLineEditing",
	},
	event = { "User KittyScrollbackLaunch" },
	-- version = '*', -- latest stable version, may have breaking changes if major version changed
	-- version = '^6.0.0', -- pin major version, include fixes and features that do not have breaking changes
	config = function()
		require("kitty-scrollback").setup({
			search = {
				callbacks = {
					after_ready = function()
						vim.api.nvim_feedkeys("?", "n", false)
					end,
				},
			},
			opts = {
				status_window = {
					icons = { nvim = "" },
					style_simple = false,
				},
			},
		})
	end,
}
