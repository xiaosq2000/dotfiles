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
-- Move by display line, but only for bare j/k. With a count, fall back to real
-- lines so that 'relativenumber' gutter jumps (10j) land where they claim to.
map({ "n", "v" }, "j", "v:count == 0 ? 'gj' : 'j'", {
	expr = true,
	desc = "Down (display line, or real line with a count)",
})
map({ "n", "v" }, "k", "v:count == 0 ? 'gk' : 'k'", {
	expr = true,
	desc = "Up (display line, or real line with a count)",
})
map({ "n", "v" }, "gj", "j", { desc = "Down (real line)" })
map({ "n", "v" }, "gk", "k", { desc = "Up (real line)" })

-- <C-a> is tmux's prefix, so increment moves off it. `ga` is not free either --
-- it is the built-in :ascii -- so use the +/- pair, whose built-in
-- first-non-blank line motions are already covered by <cr> and k.
map({ "n", "v" }, "+", "<c-a>", { desc = "Increment number" })
map({ "n", "v" }, "-", "<c-x>", { desc = "Decrement number" })

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
--------------------------------- banner comment -------------------------------
--------------------------------------------------------------------------------
-- Wrap the current line's text in a centered banner comment; a blank line just
-- becomes a single rule.
--
-- The fill character doubles as the comment leader -- ----, ####, %%%%, //// are
-- each a valid line comment in the language that uses them -- so it comes from
-- 'commentstring' instead of being chosen by hand.
--
-- Not a luasnip snippet (the old TODO here): a snippet expands a template as you
-- type, whereas a banner reads the line that already exists and computes widths
-- from it. The previous keystroke recipe (ref: https://vi.stackexchange.com/a/421)
-- ignored indentation and clobbered the unnamed register; this does neither.
local function banner()
	-- First char of the comment prefix, not the last, so `/* %s */` yields `/`
	-- (valid as ////) rather than `*` (which starts nothing).
	local prefix = vim.trim((vim.bo.commentstring:gsub("%%s.*", "")))
	local fill = prefix ~= "" and prefix:sub(1, 1) or "#"

	local line = vim.api.nvim_get_current_line()
	local indent = line:match("^%s*")
	local text = vim.trim(line)

	-- Tabs are one byte but occupy 'tabstop' columns, so measure the indent by
	-- display width to keep the right edge flush.
	local width = vim.bo.textwidth > 0 and vim.bo.textwidth or 80
	local avail = math.max(width - vim.fn.strdisplaywidth(indent), 6)
	local rule = indent .. fill:rep(avail)

	local lines = { rule }
	if text ~= "" then
		local inner = " " .. text .. " "
		local pad = avail - vim.fn.strdisplaywidth(inner)
		-- An over-long title overflows the width rather than losing its leader.
		local left = math.max(math.floor(pad / 2), 3)
		local right = math.max(pad - left, 3)
		lines = { rule, indent .. fill:rep(left) .. inner .. fill:rep(right), rule }
	end

	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, row - 1, row, false, lines)
	vim.api.nvim_win_set_cursor(0, { row + #lines - 1, 0 })
	vim.cmd.stopinsert()
end

map("n", "<leader>b", banner, { desc = "Banner comment" })

--------------------------------------------------------------------------------
----------------------------------- utilities ----------------------------------
--------------------------------------------------------------------------------
-- Count a character before the cursor on the current line. Deliberately left on
-- the command line without <cr> so the target character can be edited first.
-- ref: https://stackoverflow.com/a/63521765
-- TODO: to substitute variables.
map(
	"n",
	"<leader>uc",
	":echo count(getline('.')[0:getpos('.')[2]-1], '*')",
	{ desc = "Count char before cursor" }
)
