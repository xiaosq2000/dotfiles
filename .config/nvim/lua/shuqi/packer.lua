vim.cmd [[packadd packer.nvim]]
return require('packer').startup(function(use)
    -- packer.nvim can manage itself
    use 'wbthomason/packer.nvim'
    -- parser engine
    use "nvim-treesitter/nvim-treesitter"
    -- fuzzy finder
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.2',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }
    use {
        -- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
        "williamboman/mason.nvim",
        -- bridge
        "williamboman/mason-lspconfig.nvim",
        -- LSP configurator
        "neovim/nvim-lspconfig",
    }
    -- auto-complete
    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-cmdline'
    use 'hrsh7th/nvim-cmp'
    use 'saadparwaiz1/cmp_luasnip'
    -- LaTex
    use 'lervag/vimtex'
    -- vim-tmux
    use 'christoomey/vim-tmux-navigator'
    -- open a file with cursor at last place
    use 'ethanholz/nvim-lastplace'
    -- snippet engine
    use {
        "L3MON4D3/LuaSnip",
        -- follow latest release.
        tag = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
        -- install jsregexp (optional!:).
        run = "make install_jsregexp"
    }
    -- colorscheme
    use({ 'rose-pine/neovim', as = 'rose-pine' })
end)
