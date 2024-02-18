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
    "nvim-treesitter/nvim-treesitter",
    -- fuzzy finder
    {
        'nvim-telescope/telescope.nvim',
        tag = '0.1.2',
        dependencies = { { 'nvim-lua/plenary.nvim' } }
    },
    {
        -- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
        "williamboman/mason.nvim",
        -- bridge
        "williamboman/mason-lspconfig.nvim",
        -- LSP configurator
        "neovim/nvim-lspconfig",
    },
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
    { "catppuccin/nvim", name = "catppuccin", priority = 1000 }
}

local opts = {}

require("lazy").setup(plugins, opts)
