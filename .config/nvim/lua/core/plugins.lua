local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
    -- parser engine
    { 'nvim-treesitter/nvim-treesitter',  build = ':TSUpdate' },
    -- fuzzy finder
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.2',
        dependencies = { { 'nvim-lua/plenary.nvim' } }
    },
    -- LSP configurator
    { "neovim/nvim-lspconfig" },
    -- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
    { "williamboman/mason.nvim" },
    -- a bridge between nvim-lspconfig and mason.
    { "williamboman/mason-lspconfig.nvim" },
    -- non-LSP tools configurator, like linters and formatters.
    { 'nvimtools/none-ls.nvim' },
    -- auto-complete
    {
        'hrsh7th/cmp-nvim-lsp',
        'hrsh7th/cmp-buffer',
        'hrsh7th/cmp-path',
        'hrsh7th/cmp-cmdline',
        'hrsh7th/nvim-cmp',
        'saadparwaiz1/cmp_luasnip',
    },
    -- LaTex
    'lervag/vimtex',
    -- vim-tmux
    'christoomey/vim-tmux-navigator',
    -- open a file with cursor at last place
    'ethanholz/nvim-lastplace',
    -- snippet engine
    {
        "L3MON4D3/LuaSnip",
        -- follow latest release.
        version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
        -- install jsregexp (optional!).
        build = "make install_jsregexp"
    },
    -- colorscheme
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
    {
        "nvim-tree/nvim-tree.lua",
        version = "*",
        lazy = false,
        dependencies = {
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("nvim-tree").setup {}
        end,
    }
}

local opts = {}

require("lazy").setup(plugins, opts)
