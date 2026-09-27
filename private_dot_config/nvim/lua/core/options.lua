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
vim.o.smartindent = true

--------------------------------------------------------------------------------
------------------------------------- undo -------------------------------------
--------------------------------------------------------------------------------
vim.o.undofile = true

--------------------------------------------------------------------------------
------------------------------------ search ------------------------------------
--------------------------------------------------------------------------------
vim.o.inccommand = "split"

-- 'hlsearch' stays on because the ui2 message UI below stops :s///c from
-- drawing its current match with IncSearch, which leaves CurSearch as the only
-- highlight. That is so on 0.12.5 and fixed on 0.13 nightly (checked on
-- 2026-09-27). So that matches do not linger, any normal-mode key other than a
-- search motion clears them.
vim.o.hlsearch = true
local search_keys = { n = true, N = true, ["*"] = true, ["#"] = true }
vim.on_key(function(_, typed)
	if typed == "" or vim.v.hlsearch == 0 or vim.fn.mode() ~= "n" then
		return
	end
	if not search_keys[vim.fn.keytrans(typed)] then
		vim.schedule(vim.cmd.nohlsearch)
	end
end, vim.api.nvim_create_namespace("user.auto_nohlsearch"))

--------------------------------------------------------------------------------
--------------------------------- diagnostics ----------------------------------
--------------------------------------------------------------------------------
-- Everything else is the default, and 'winborder' draws the float's border.
-- Only the cursor line gets inline text, so the rest of the buffer stays quiet.
vim.diagnostic.config({
	virtual_text = { current_line = true },
	float = { source = "if_many" },
})

--------------------------------------------------------------------------------
---------------------------------- message ui ----------------------------------
--------------------------------------------------------------------------------
-- Experimental message UI, not available before nvim 0.12.
local ok, ui2 = pcall(require, "vim._core.ui2")
if ok then
	ui2.enable({
		msg = {
			-- Every kind not listed in `targets` goes to the message window.
			-- With 'cmdheight' 0, a message left in the cmdline hides the next
			-- :s///c prompt; plugin errors sent through vim.notify, such as
			-- dooing's "items due", did that. It is open upstream as
			-- neovim/neovim#42116 and still happens on 0.13 nightly (checked
			-- on 2026-09-27).
			target = "msg",
			targets = {
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
