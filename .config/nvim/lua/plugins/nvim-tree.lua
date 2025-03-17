return {
	"nvim-tree/nvim-tree.lua",
	version = "*",
	lazy = false,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("nvim-tree").setup({
			sort = {
				sorter = "case_sensitive",
			},
			view = {
				width = 30,
			},
			renderer = {
				group_empty = true,
			},
			filters = {
				git_ignored = false,
			},
		})
		-- Use <C-Q> to open or close.
		vim.keymap.set({ "i", "n" }, "<C-Q>", "<CMD>NvimTreeOpen<CR>", { silent = true })
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "NvimTree",
			callback = function()
				vim.keymap.set("n", "<C-Q>", ":NvimTreeClose<CR>", { buffer = true, silent = true })
			end,
		})
	end,
}
