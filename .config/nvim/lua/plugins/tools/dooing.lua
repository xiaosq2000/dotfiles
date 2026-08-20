-- Neither :Dooing nor :DooingLocal ever closes the window -- both only open or
-- re-render it -- so upstream's "toggle" keymaps can put the list up and leave
-- `q` as the one way back out. Close it when it already shows the list being
-- asked for, and open it otherwise, which keeps the half of that behaviour
-- worth having: the other key switches lists while the window is up.
---@param cmd string
---@param want_global boolean
local function toggle(cmd, want_global)
	return function()
		local ui = require("dooing.ui")
		local global = require("dooing.config").options.save_path
		-- Tested against the global path rather than the project one because
		-- get_project_todo_path() always reports <git root>/dooing.json, so a
		-- project file created under a custom name never matches itself.
		local current = require("dooing.state").current_save_path or global
		if ui.is_window_open() and (current == global) == want_global then
			ui.close_window()
		else
			vim.cmd(cmd)
		end
	end
end

return {
	"atiladefreitas/dooing",
	-- Deliberately not lazy-loaded behind the keys below. The "N items due"
	-- notification fires from setup(), so a dooing that waits for <leader>td
	-- could only ever warn about deadlines you already went looking for --
	-- which is the half of the job a todo list is meant to do for you.
	event = "VeryLazy",
	cmd = { "Dooing", "DooingLocal", "DooingDue" },
	-- plugin/dooing.vim runs `setup()` with no arguments, i.e. a second setup
	-- against pure defaults. It leaves `opts` below intact -- it runs first --
	-- but its <leader>td/tD/tN mappings outlive it, so the plugin's own
	-- never-closing handlers end up shadowing the toggles in `keys`, and the
	-- due-date notification fires twice. That file guards on g:loaded_dooing,
	-- so claiming the flag here leaves lazy's `opts` as the only setup.
	init = function()
		vim.g.loaded_dooing = 1
	end,
	-- The three entry points stay on <leader>t, upstream's own prefix, so the
	-- README's keybinding table reads true here. Everything else in the plugin
	-- is buffer-local to the todo window (see `keymaps` below).
	keys = {
		{ "<leader>td", toggle("Dooing", true), desc = "Todos (global)" },
		{
			"<leader>tD",
			toggle("DooingLocal", false),
			desc = "Todos (this project)",
		},
		{ "<leader>tN", "<cmd>DooingDue<cr>", desc = "Todos due" },
	},
	opts = {
		-- v3's redesigned interface: status sections, tree connectors for
		-- subtasks, right-aligned metadata. It ships off by default only so
		-- that upgrading never rearranges an existing setup.
		ui = {
			style = "modern",
		},

		-- A fixed 55x20 box ignores the terminal it is drawn in. Floors keep it
		-- usable on a split-down-the-middle kitty window.
		window = {
			dimensions = function()
				return {
					width = math.max(55, math.floor(vim.o.columns * 0.5)),
					height = math.max(20, math.floor(vim.o.lines * 0.6)),
				}
			end,
		},

		-- The global list lives in the Nutstore folder so that it follows
		-- the machine. Concurrency is barely a worry: every open re-reads the
		-- file and every action writes it straight back, so the only way to
		-- lose an edit is to have the window up on two machines at once. The
		-- fallback is not optional, though -- save_todos() drops the write
		-- when io.open() fails and says nothing about it, so on a machine
		-- with no Nutstore the list would read back empty and swallow
		-- everything typed into it.
		save_path = (function()
			local dir = vim.fn.expand("~/Nutstore Files/Nutstore")
			if vim.fn.isdirectory(dir) == 1 then
				return dir .. "/dooing_todos.json"
			end
			return vim.fn.stdpath("data") .. "/dooing_todos.json"
		end)(),

		-- jq is on PATH, so the store stays line-diffable. Matters for the
		-- per-project files, which are the ones that end up in a repo.
		pretty_print_json = true,

		per_project = {
			-- Whether a project's todos are shared or personal is a per-repo
			-- call, so ask rather than guess.
			auto_gitignore = "prompt",
		},

		keymaps = {
			-- Owned by the `keys` block above. setup() maps these last, so
			-- leaving them on would replace the toggles with handlers that
			-- only ever open -- the g:loaded_dooing flag above closes the
			-- other route to the same problem.
			toggle_window = false,
			open_project_todo = false,
			show_due_notification = false,

			-- Upstream puts three of the in-window actions behind <leader>,
			-- where they are ungrouped one-offs that break the one-concept-per
			-- -prefix rule in which-key.lua -- and <leader>p in particular is
			-- indistinguishable from a global mapping until you notice it only
			-- works here. They belong with the other modal keys instead: the
			-- todo buffer is 'nomodifiable', so o/n/X are free.
			create_nested_task = "o", -- opens a subtask below, as o does a line
			open_todo_scratchpad = "n", -- notes
			remove_duplicates = "X",
		},
	},
}
