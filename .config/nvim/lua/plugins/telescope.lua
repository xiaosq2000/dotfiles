-- fuzzy finder
return {
    'nvim-telescope/telescope.nvim',
    enable = "false",
    -- tag = '0.1.5',
    dependencies = { { 'nvim-lua/plenary.nvim' }, { 'nvim-telescope/telescope-ui-select.nvim' } },
    config = function()
        local builtin = require('telescope.builtin')
        --
        vim.keymap.set('n', '<leader>fs', function()
            builtin.grep_string({ search = vim.fn.input("Grep > ") });
        end)
        --
        vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
        vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
        vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
        vim.keymap.set('n', '<leader>fhp', builtin.help_tags, {})
        --
        require("telescope").load_extension("ui-select")
        -- Insert file path
        local telescope = require('telescope.builtin')
        local actions = require('telescope.actions')
        local action_state = require('telescope.actions.state')

        -- Custom function to insert filepath at cursor
        local function insert_filepath(filepath)
            -- Get current cursor position
            local pos = vim.api.nvim_win_get_cursor(0)
            local row = pos[1] - 1 -- Convert to 0-based index
            local col = pos[2]

            -- Get current line
            local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]

            -- Insert filepath at cursor position
            local new_line = string.sub(line, 1, col) .. filepath .. string.sub(line, col + 1)
            vim.api.nvim_buf_set_lines(0, row, row + 1, false, { new_line })

            -- Move cursor to end of inserted filepath
            vim.api.nvim_win_set_cursor(0, { row + 1, col + #filepath })
        end

        -- Custom file search function
        local function file_search_and_insert()
            telescope.find_files({
                attach_mappings = function(prompt_bufnr, map)
                    -- Override default select action
                    actions.select_default:replace(function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        if selection then
                            insert_filepath(selection.value)
                        end
                    end)
                    return true
                end,
            })
        end

        -- Set up the keybinding
        vim.keymap.set('n', '<leader>fi', file_search_and_insert,
            { noremap = true, silent = true, desc = 'Search file and insert path' })
    end
}
