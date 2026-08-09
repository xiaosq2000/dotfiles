--- vim.keymap.set is already non-recursive by default; this only adds silent.
local function map(mode, lhs, rhs, opts)
	vim.keymap.set(
		mode,
		lhs,
		rhs,
		vim.tbl_extend("force", { silent = true }, opts or {})
	)
end

--------------------------------------------------------------------------------
------------------------------------ modes -------------------------------------
--------------------------------------------------------------------------------
map("i", "jk", "<esc>", { desc = "Leave insert mode" })
map("t", "<esc>", [[<C-\><C-n>]], { desc = "Leave terminal mode" })

--------------------------------------------------------------------------------
----------------------------------- motion -------------------------------------
--------------------------------------------------------------------------------
-- Move by display line by default; g-prefixed variants move by real line.
map({ "n", "v" }, "j", "gj", { desc = "Down (display line)" })
map({ "n", "v" }, "k", "gk", { desc = "Up (display line)" })
map({ "n", "v" }, "gj", "j", { desc = "Down (real line)" })
map({ "n", "v" }, "gk", "k", { desc = "Up (real line)" })

-- <C-a> is tmux's prefix, so increment moves to a free key.
map({ "n", "v" }, "ga", "<c-a>", { desc = "Increment number" })

--------------------------------------------------------------------------------
------------------------------------- edit -------------------------------------
--------------------------------------------------------------------------------
map(
	"n",
	"<leader>ec",
	"<cmd>vsp ~/.config/nvim/<cr>",
	{ desc = "Edit nvim config" }
)

--------------------------------------------------------------------------------
----------------------------------- clipboard ----------------------------------
--------------------------------------------------------------------------------
map("v", "<enter>", '"+y', { desc = "Yank selection to system clipboard" })
map(
	"n",
	"<leader>yp",
	"<cmd>let @+ = expand('%:p')<cr>",
	{ desc = "Yank absolute path" }
)
map(
	"n",
	"<leader>yr",
	"<cmd>let @+ = expand('%')<cr>",
	{ desc = "Yank relative path" }
)

--------------------------------------------------------------------------------
------------------------------------ banner ------------------------------------
--------------------------------------------------------------------------------
-- Wrap the current line in a centered 80-column banner comment.
-- ref: https://vi.stackexchange.com/a/421
-- TODO: use luasnip; adapt to indent elegantly
for _, char in ipairs({ "/", "%", "-", "#" }) do
	local recipe = ("<esc><cmd>center 80<cr>hhv0r%sA<space><esc>40A%s<esc>d80<bar>YppVr%skk."):format(
		char,
		char,
		char
	)
	map(
		{ "n", "i" },
		"<leader>c" .. char,
		recipe,
		{ desc = ("Banner comment (%s)"):format(char) }
	)
end

-- Count a character before the cursor on the current line. Deliberately left on
-- the command line without <cr> so the target character can be edited first.
-- ref: https://stackoverflow.com/a/63521765
-- TODO: to substitute variables.
map(
	"n",
	"<leader>cl",
	":echo count(getline('.')[0:getpos('.')[2]-1], '*')",
	{ desc = "Count char before cursor" }
)
