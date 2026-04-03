return {
	"j-hui/fidget.nvim",
	version = "*",
	event = "LspAttach",
	opts = {
		notification = {
			-- Keep noice/nvim-notify as the active vim.notify backend.
			override_vim_notify = false,
		},
	},
}
