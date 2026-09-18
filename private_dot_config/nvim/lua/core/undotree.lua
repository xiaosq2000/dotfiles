-- Neovim 0.12 ships an undo-tree viewer as an opt package (:h package-undotree),
-- so it has to be packadd'ed before `require("undotree")` can resolve.
--
-- That has to happen at first use rather than at startup: lazy.nvim rewrites
-- 'runtimepath' wholesale during setup, which drops the entry :packadd added and
-- leaves the module unfindable. Claiming the package's own load guard keeps its
-- plugin/undotree.lua from re-running and replacing the :Undotree defined below
-- with its own, non-toggling version.
local function packadd()
	vim.g.loaded_undotree_plugin = true
	vim.cmd.packadd("nvim.undotree")
end

--------------------------------------------------------------------------------
------------------------------------ toggle ------------------------------------
--------------------------------------------------------------------------------
-- The package defaults to a 30-column split, but a node line reads
-- `*    128    (2026/08/14 09:31:07)` once an entry is older than half a day,
-- and 'wrap' is off in that window, so the timestamp would be cut off.
local WIDTH = 40

-- Browsing the tree is destructive by design: the package undoes to the node
-- under the cursor on every CursorMoved, so there is no separate "apply" step,
-- and closing the window just leaves the buffer wherever the cursor stopped.
-- Record the starting point so <esc> can be a real cancel.
local function toggle()
	packadd()

	local src = vim.api.nvim_get_current_buf()
	local seq = vim.fn.undotree(src).seq_cur

	-- open() is itself a toggle, returning true when it closed an open window.
	-- `botright` keeps the panel a full-height sidebar instead of splitting
	-- whichever window happened to be current.
	local command = ("vertical botright %dnew"):format(WIDTH)
	if require("undotree").open({ command = command }) then
		return
	end

	-- open() leaves the cursor in the tree window it just created.
	vim.b[vim.api.nvim_get_current_buf()].undotree_origin =
		{ buf = src, seq = seq }
end

vim.keymap.set("n", "<leader>ut", toggle, {
	silent = true,
	desc = "Toggle undo tree",
})

-- Shadow the command the package defines so both entry points remember the
-- origin, and so :Undotree honours WIDTH too.
vim.api.nvim_create_user_command("Undotree", toggle, {
	desc = "Toggle undo tree",
})

--------------------------------------------------------------------------------
----------------------------------- fold text ----------------------------------
--------------------------------------------------------------------------------
-- The package folds linear runs longer than three nodes, and the global
-- 'foldtext' then renders each one as `<first line> ... <last line>` with
-- treesitter colours -- in this buffer that means
-- `*  62  (2026/08/13 19:48:56) ... *  66`, well past WIDTH and cut off because
-- 'wrap' is off. A fold here only needs to say how much history it stands for.
--- Global because 'foldtext' can only reference a Vimscript-visible function.
function _G.undotree_foldtext()
	local first = vim.fn.getline(vim.v.foldstart)
	local last = vim.fn.getline(vim.v.foldend)

	-- Keep the branch columns so the summary stays aligned with the nodes it
	-- sits between.
	local graph = first:match("^[|/\\ ]*") or ""
	local from = first:match("%d+") or "?"
	local to = last:match("%d+") or "?"

	return ("%s⋯ %d states (%s-%s)"):format(
		graph,
		vim.v.foldend - vim.v.foldstart + 1,
		from,
		to
	)
end

--------------------------------------------------------------------------------
------------------------------------ panel -------------------------------------
--------------------------------------------------------------------------------
--- Resolved per open so the panel follows a runtime :colorscheme change.
local function set_highlights()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
	local dim = vim.api.nvim_get_hl(0, { name = "NonText", link = false })

	-- Needs an explicit background: it gets remapped onto Normal below, and a
	-- group carrying no background of its own would drop the window back to the
	-- default backdrop.
	vim.api.nvim_set_hl(0, "UndotreeDim", { fg = dim.fg, bg = normal.bg })
	vim.api.nvim_set_hl(0, "UndotreeNode", { link = "Special", default = true })
	vim.api.nvim_set_hl(0, "UndotreeSeq", { link = "Number", default = true })
	vim.api.nvim_set_hl(0, "UndotreeTime", { link = "Comment", default = true })
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("user.undotree", { clear = true }),
	pattern = "nvim-undotree",
	callback = function(args)
		set_highlights()

		-- Every node already carries its sequence number in the text, so the
		-- gutter is pure noise here.
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
		vim.opt_local.foldcolumn = "0"
		vim.opt_local.winfixwidth = true

		-- Both are window-local, so the code-oriented global fold rendering is
		-- left alone. Without the 'fillchars' override a folded node trails a
		-- row of dots to the edge of the panel.
		vim.opt_local.foldtext = "v:lua.undotree_foldtext()"
		vim.opt_local.fillchars:append({ fold = " " })

		-- Assigning 'filetype' makes Neovim's syntax loader run `syntax clear`
		-- on this buffer, and that happens after this handler -- it wipes the
		-- package's own timestamp rule along with anything defined here, which
		-- is why the panel renders in a single colour out of the box.
		-- matchadd() lives in the window instead of the syntax engine, so it
		-- survives; the panel gets a fresh window on every open, so these do not
		-- accumulate. The sequence number is what :undo takes as an argument,
		-- which makes it the one part of a node worth picking out.
		vim.fn.matchadd("UndotreeTime", [[([^)]*)]])
		vim.fn.matchadd("UndotreeNode", [[\*]])
		vim.fn.matchadd("UndotreeSeq", [[\*\s\+\zs\d\+]])

		-- The branch connectors are virtual lines the package hardcodes to
		-- `Normal`, so the scaffolding draws as loudly as the nodes and has no
		-- highlight group of its own to retune. Remapping the window's Normal
		-- is the only lever over them, and it costs nothing on the node lines:
		-- every part of those that carries meaning is matched above.
		vim.opt_local.winhighlight = "Normal:UndotreeDim"

		vim.keymap.set("n", "q", "<cmd>close<cr>", {
			buffer = args.buf,
			desc = "Close, keeping the state under the cursor",
		})

		vim.keymap.set("n", "<esc>", function()
			-- Read before closing: the tree buffer is 'bufhidden' = wipe.
			local origin = vim.b[args.buf].undotree_origin
			vim.cmd.close()

			if origin and vim.api.nvim_buf_is_valid(origin.buf) then
				vim.api.nvim_buf_call(origin.buf, function()
					vim.cmd.undo({ origin.seq, mods = { silent = true } })
				end)
			end
		end, {
			buffer = args.buf,
			desc = "Close, restoring the state from before the tree opened",
		})
	end,
	desc = "Undo tree panel: quiet gutter, q to keep, <esc> to cancel",
})
