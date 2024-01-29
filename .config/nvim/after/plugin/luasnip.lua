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

-- Load all snippets from the nvim/LuaSnip directory at startup
-- require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/lua/shuqi/LuaSnip" })

-- Lazy-load snippets, i.e. only load when required, e.g. for a given filetype
require("luasnip.loaders.from_lua").lazy_load({ paths = "~/.config/nvim/lua/shuqi/LuaSnip" })

-- reload luasnip
vim.keymap.set('n', '<leader>L', '<Cmd>lua require("luasnip.loaders.from_lua").load({paths = "~/.config/nvim/lua/shuqi/LuaSnip/"})<CR>')

-- vertically open snippets for filetype tex to quick edit
vim.keymap.set('n', '<leader>Lt', '<Cmd>vsp ~/.config/nvim/lua/shuqi/LuaSnip/tex<CR>')
