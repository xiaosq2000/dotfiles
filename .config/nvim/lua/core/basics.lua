--------------------------------------------------------------------------------
------------------------------------ remap -------------------------------------
--------------------------------------------------------------------------------
vim.g.mapleader = "\\"
local opts = { noremap = true, silent = true }

vim.keymap.set({ "i", "s" }, "jk", "<esc>", opts)
vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], opts)

vim.keymap.set({ "n", "v" }, "j", "gj", opts)
vim.keymap.set({ "n", "v" }, "gj", "j", opts)
vim.keymap.set({ "n", "v" }, "k", "gk", opts)
vim.keymap.set({ "n", "v" }, "gk", "k", opts)

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.keymap.set("n", "<leader>ec", "<cmd>vsp ~/.config/nvim/<cr>", opts)

-- copy to system clipboard
vim.keymap.set("v", "<enter>", "\"+y", opts)
vim.keymap.set("n", "<leader>yp", ":let @+ = expand('%:p')<cr>", opts)
vim.keymap.set("n", "<leader>yr", ":let @+ = expand('%')<cr>", opts)

-- comment block, ref: https://vi.stackexchange.com/a/421
-- Todo: adapt to indent
-- Todo: elegantly
vim.keymap.set({ "n", "i" }, "<leader>c/", "<esc><cmd>center 80<cr>hhv0r/A<space><esc>40A/<esc>d80<bar>YppVr/kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c%", "<esc><cmd>center 80<cr>hhv0r%A<space><esc>40A%<esc>d80<bar>YppVr%kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c-", "<esc><cmd>center 80<cr>hhv0r-A<space><esc>40A-<esc>d80<bar>YppVr-kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c#", "<esc><cmd>center 80<cr>hhv0r#A<space><esc>40A#<esc>d80<bar>YppVr#kk.", opts)
-- Todo: comment with ctrl+/ like vscode

-- count specfic characters before cursor on the current line
-- ref: https://stackoverflow.com/a/63521765
-- Todo: to substitute variables.
vim.keymap.set({ "n" }, "<leader>cl", ":echo count(getline('.')[0:getpos('.')[2]-1], '*')", opts)

--------------------------------------------------------------------------------
--------------------------------- line number ----------------------------------
--------------------------------------------------------------------------------
vim.opt.number = true
vim.opt.relativenumber = true

--------------------------------------------------------------------------------
------------------------------------ indent ------------------------------------
--------------------------------------------------------------------------------
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smarttab = true
vim.opt.smartindent = true

--------------------------------------------------------------------------------
----------------------------- swap and backup file -----------------------------
--------------------------------------------------------------------------------
vim.opt.swapfile = false
vim.opt.backup = false

--------------------------------------------------------------------------------
------------------------------------ search ------------------------------------
--------------------------------------------------------------------------------
vim.opt.hlsearch = false
vim.opt.incsearch = true

--------------------------------------------------------------------------------
------------------------------------ colors ------------------------------------
--------------------------------------------------------------------------------
vim.opt.termguicolors = true

--------------------------------------------------------------------------------
------------------------------------- wrap -------------------------------------
--------------------------------------------------------------------------------
vim.opt.wrap = true
