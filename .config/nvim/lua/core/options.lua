-- Leader keys must be set before lazy.nvim evaluates any spec, since `keys =`
-- entries resolve <leader> at spec time.
vim.g.mapleader = " "
-- Free again now that mapleader has moved to <space>, and it is what vimtex's
-- documentation assumes.
vim.g.maplocalleader = "\\"

-- Yazi owns directory browsing.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

--------------------------------------------------------------------------------
------------------------------------- ui ---------------------------------------
--------------------------------------------------------------------------------
vim.o.cmdheight = 0
vim.o.winborder = "rounded"
vim.o.number = true
vim.o.relativenumber = true
vim.o.termguicolors = true
vim.o.wrap = true
vim.o.updatetime = 300
-- views can only be fully collapsed with the global statusline
vim.o.laststatus = 3

--------------------------------------------------------------------------------
------------------------------------ indent ------------------------------------
--------------------------------------------------------------------------------
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.smartindent = true

--------------------------------------------------------------------------------
----------------------------- swap and backup file -----------------------------
--------------------------------------------------------------------------------
vim.o.swapfile = true
vim.o.backup = false
vim.o.undofile = true

--------------------------------------------------------------------------------
------------------------------------ search ------------------------------------
--------------------------------------------------------------------------------
vim.o.hlsearch = false
vim.o.incsearch = true
vim.o.inccommand = "split"

--------------------------------------------------------------------------------
--------------------------------- diagnostics ----------------------------------
--------------------------------------------------------------------------------
vim.diagnostic.config({
	underline = true,
	signs = true,
	virtual_text = false,
	virtual_lines = false,
	float = {
		show_header = true,
		source = "if_many",
		border = "rounded",
		focusable = true,
	},
	update_in_insert = false,
	severity_sort = false,
})

--------------------------------------------------------------------------------
---------------------------------- message ui ----------------------------------
--------------------------------------------------------------------------------
-- Experimental message UI, not available before nvim 0.12.
local ok, ui2 = pcall(require, "vim._core.ui2")
if ok then
	ui2.enable({
		msg = {
			targets = {
				echo = "msg",
				echomsg = "msg",
				lua_print = "msg",
				bufwrite = "msg",
				quickfix = "msg",
				undo = "msg",

				list_cmd = "pager",
				shell_out = "pager",
				shell_err = "pager",
				verbose = "pager",
				lua_error = "pager",
				rpc_error = "pager",
			},
			msg = { height = 0.25, timeout = 2500 },
			cmd = { height = 0.35 },
			dialog = { height = 0.45 },
			pager = { height = 0.7 },
		},
	})
end
