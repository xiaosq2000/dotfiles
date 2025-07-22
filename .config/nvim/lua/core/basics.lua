--------------------------------------------------------------------------------
------------------------------------ remap -------------------------------------
--------------------------------------------------------------------------------
vim.g.mapleader = "\\"
local opts = { noremap = true, silent = true }

vim.keymap.set({ "i" }, "jk", "<esc>", opts)
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], opts)

vim.keymap.set({ "n", "v" }, "j", "gj", opts)
vim.keymap.set({ "n", "v" }, "gj", "j", opts)
vim.keymap.set({ "n", "v" }, "k", "gk", opts)
vim.keymap.set({ "n", "v" }, "gk", "k", opts)

vim.keymap.set({ "n", "v" }, "ga", "<c-a>", opts)

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.keymap.set("n", "<leader>ec", "<cmd>vsp ~/.config/nvim/<cr>", opts)

-- copy to system clipboard
vim.keymap.set("v", "<enter>", '"+y', opts)
vim.keymap.set("n", "<leader>yp", ":let @+ = expand('%:p')<cr>", opts)
vim.keymap.set("n", "<leader>yr", ":let @+ = expand('%')<cr>", opts)

-- comment block, ref: https://vi.stackexchange.com/a/421
-- TODO: adapt to indent elegantly
vim.keymap.set({ "n", "i" }, "<leader>c/", "<esc><cmd>center 80<cr>hhv0r/A<space><esc>40A/<esc>d80<bar>YppVr/kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c%", "<esc><cmd>center 80<cr>hhv0r%A<space><esc>40A%<esc>d80<bar>YppVr%kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c-", "<esc><cmd>center 80<cr>hhv0r-A<space><esc>40A-<esc>d80<bar>YppVr-kk.", opts)
vim.keymap.set({ "n", "i" }, "<leader>c#", "<esc><cmd>center 80<cr>hhv0r#A<space><esc>40A#<esc>d80<bar>YppVr#kk.", opts)

-- count specfic characters before cursor on the current line
-- ref: https://stackoverflow.com/a/63521765
-- TODO: to substitute variables.
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

--------------------------------------------------------------------------------
--------------------------------- status line ----------------------------------
--------------------------------------------------------------------------------
-- views can only be fully collapsed with the global statusline
vim.opt.laststatus = 3

--------------------------------------------------------------------------------
--------------------------------- diagnostics ----------------------------------
--------------------------------------------------------------------------------
-- vim.diagnostic.config({
--     virtual_text = true,
--     virtual_lines = true
-- })

--------------------------------------------------------------------------------
----------------------------------- folding ------------------------------------
--------------------------------------------------------------------------------
vim.o.foldenable = true
vim.o.foldlevel = 99
vim.o.foldmethod = "expr"
vim.o.foldtext = ""
vim.opt.foldcolumn = "0"
vim.opt.fillchars:append({ fold = " " })
-- Default to treesitter folding
vim.o.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
-- Prefer LSP folding if client supports it
vim.api.nvim_create_autocmd('LspAttach', {
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client and client:supports_method('textDocument/foldingRange') then
            vim.wo.foldexpr = 'v:lua.vim.lsp.foldexpr()'
            vim.wo.foldmethod = 'expr'
        end
    end,
})
