-- auto-complete
return {
    'saghen/blink.cmp',
    -- optional: provides snippets for the snippet source
    dependencies = { { 'rafamadriz/friendly-snippets' }, { 'L3MON4D3/LuaSnip', version = 'v2.*' } },

    -- use a release tag to download pre-built binaries
    version = '*',
    -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
    -- build = 'cargo build --release',
    -- If you use nix, you can build from source using latest nightly rust with:
    -- build = 'nix run .#build-plugin',

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        -- 'default' for mappings similar to built-in completion
        -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
        -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
        -- See the full "keymap" documentation for information on defining your own keymap.
        keymap = {
            preset = 'enter',
            cmdline = {
                preset = 'enter',
            },
            -- ['<CR>'] = { 'select_and_accept', 'fallback' },
            -- ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
            -- ['<C-e>'] = { 'cancel' },
            -- ['<Tab>'] = { 'select_next', 'fallback' },
            -- ['<S-Tab>'] = { 'select_prev', 'fallback' },
            -- ['<C-n>'] = { 'snippet_forward', 'fallback' },
            -- ['<C-p>'] = { 'snippet_forward', 'fallback' },
            -- ['<Up>'] = { 'snippet_forward', 'fallback' },
            -- ['<Down>'] = { 'snippet_backward', 'fallback' },
            ['<A-1>'] = { function(cmp) cmp.accept({ index = 1 }) end },
            ['<A-2>'] = { function(cmp) cmp.accept({ index = 2 }) end },
            ['<A-3>'] = { function(cmp) cmp.accept({ index = 3 }) end },
            ['<A-4>'] = { function(cmp) cmp.accept({ index = 4 }) end },
            ['<A-5>'] = { function(cmp) cmp.accept({ index = 5 }) end },
            ['<A-6>'] = { function(cmp) cmp.accept({ index = 6 }) end },
            ['<A-7>'] = { function(cmp) cmp.accept({ index = 7 }) end },
            ['<A-8>'] = { function(cmp) cmp.accept({ index = 8 }) end },
            ['<A-9>'] = { function(cmp) cmp.accept({ index = 9 }) end },
            ['<A-0>'] = { function(cmp) cmp.accept({ index = 10 }) end },
        },

        completion = {
            list = { selection = { preselect = false, auto_insert = true } },
            trigger = { show_in_snippet = false },
        },

        appearance = {
            -- Sets the fallback highlight groups to nvim-cmp's highlight groups
            -- Useful for when your theme doesn't support blink.cmp
            -- Will be removed in a future release
            use_nvim_cmp_as_default = true,
            -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
            -- Adjusts spacing to ensure icons are aligned
            nerd_font_variant = 'mono'
        },

        snippets = {
            preset = 'luasnip'
        },

        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
    },
    opts_extend = { "sources.default" }
}
