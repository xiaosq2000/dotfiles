-- fuzzy finder
return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = { { 'nvim-lua/plenary.nvim' }, { 'nvim-telescope/telescope-ui-select.nvim' } },
    config = function()
        local builtin = require('telescope.builtin')
        --
        vim.keymap.set('n', '<space>fs', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") });
        end)
        --
        vim.keymap.set('n', '<space>ff', builtin.find_files, {})
        vim.keymap.set('n', '<space>fg', builtin.live_grep, {})
        vim.keymap.set('n', '<space>fb', builtin.buffers, {})
        vim.keymap.set('n', '<space>fhp', builtin.help_tags, {})
        --
        require("telescope").load_extension("ui-select")
    end
}
