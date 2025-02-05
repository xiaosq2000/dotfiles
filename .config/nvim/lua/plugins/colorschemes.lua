return {
    {
        "rose-pine/neovim",
        name = "rose-pine",
        config = function()
            -- main, moon, dawn
            vim.cmd.colorscheme "rose-pine"
        end
    },
    {
        "catppuccin/nvim",
        name = "catppuccin",
        enabled = vim.env.KITTY_SCROLLBACK_NVIM == 'true',
        -- config = function()
        --     -- latte, frappe, macchiato, mocha
        --     vim.cmd.colorscheme "catppuccin-latte"
        -- end
    }
}
