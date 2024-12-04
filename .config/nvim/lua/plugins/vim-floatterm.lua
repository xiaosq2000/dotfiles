return {
    'voldikss/vim-floaterm',
    config = function()
        vim.keymap.set({ "i", "n" }, "<C-Q>", "<CMD>NvimTreeOpen<CR>", { silent = true })
        vim.keymap.set({ "n" }, "<F1>", ":FloatermNew<CR>", { silent = true })
        vim.keymap.set({ "t" }, "<F1>", [[<C-\><C-n>:FloatermNew<CR>]], { silent = true })
        vim.keymap.set({ "n" }, "<F2>", ":FloatermToggle<CR>", { silent = true })
        vim.keymap.set({ "t" }, "<F2>", [[<C-\><C-n>:FloatermToggle<CR>]], { silent = true })
        vim.keymap.set({ "n" }, "<F3>", ":FloatermPrev<CR>", { silent = true })
        vim.keymap.set({ "t" }, "<F3>", [[<C-\><C-n>:FloatermPrev<CR>]], { silent = true })
        vim.keymap.set({ "n" }, "<F4>", ":FloatermNext<CR>", { silent = true })
        vim.keymap.set({ "t" }, "<F4>", [[<C-\><C-n>:FloatermNext<CR>]], { silent = true })
    end
}
