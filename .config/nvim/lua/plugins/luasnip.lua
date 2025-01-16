-- snippet engine
return {
    {
        "L3MON4D3/LuaSnip",
        -- follow latest release.
        version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
        -- install jsregexp (optional!).
        build = "make install_jsregexp",
        config = function()
            local ls = require('luasnip')
            ls.config.set_config({
                -- This tells LuaSnip to remember to keep around the last snippet.
                -- You can jump back into it even if you move outside of the selection
                history = true,
                -- Enable autotriggered snippets
                enable_autosnippets = true,
                store_selection_keys = "<C-F>"
            })

            vim.keymap.set({ "i" }, "<C-F>", function() ls.expand_or_jump() end, { silent = true })
            vim.keymap.set({ "s" }, "<C-F>", function() ls.jump(1) end, { silent = true })
            vim.keymap.set({ "i", "s" }, "<C-B>", function() ls.jump(-1) end, { silent = true })
            vim.keymap.set({ "i", "s" }, "<C-E>", function()
                if ls.choice_active() then
                    ls.change_choice(1)
                end
            end, { silent = true })

            -- Load all snippets from the nvim/LuaSnip directory at startup
            -- require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/lua/core/LuaSnip" })

            -- Lazy-load snippets, i.e. only load when required, e.g. for a given filetype
            require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/lua/LuaSnip" })

            -- reload luasnip
            vim.keymap.set('n', '<leader>ll',
                '<Cmd>lua require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/lua/LuaSnip/"})<CR>')

            -- vertically open snippets for filetype tex to quick edit
            vim.keymap.set('n', '<leader>tl', '<Cmd>vsp ~/.config/nvim/lua/LuaSnip/tex<CR>')
        end
    }
}
