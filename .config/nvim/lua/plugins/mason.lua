-- portable package manager to easily install and manage LSP servers, DAP servers, linters, and formatters.
-- a bridge between nvim-lspconfig and mason.
return {
    { 
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end
    },
    {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
        require("mason-lspconfig").setup {
            automatic_installation = true,
            ensure_installed = { "ruff", "pyright", "cmake", "bashls", "lua_ls", "marksman", "dockerls", "docker_compose_language_service", "jsonls", "texlab" },

        }
        local on_attach = function(client)
            if client.name == 'ruff' then
                -- Disable hover in favor of Pyright
                client.server_capabilities.hoverProvider = false
            end
        end
        require("mason-lspconfig").setup_handlers {
            -- The first entry (without a key) will be the default handler
            -- and will be called for each installed server that doesn't have
            -- a dedicated handler.
            function(server_name) -- default handler (optional)
                require("lspconfig")[server_name].setup {}
            end,
            ["lua_ls"] = function()
                require("lspconfig").lua_ls.setup {
                    settings = {
                        Lua = {
                            diagnostics = {
                                globals = { "vim" }
                            }
                        }
                    }
                }
            end,
            ["ruff"] = function()
                require('lspconfig').ruff.setup {
                    on_attach = on_attach,
                }
            end,
            ["pyright"] = function()
                require('lspconfig').pyright.setup {
                    on_attach = on_attach,
                    settings = {
                        pyright = {
                            -- Using Ruff's import organizer
                            disableOrganizeImports = true,
                        },
                        python = {
                            analysis = {
                                -- Ignore all files for analysis to exclusively use Ruff for linting
                                ignore = { '*' },
                            },
                        },
                    },
                }
            end
        }
    end
    },
    -- non-LSP tools configurator, like linters and formatters.
    {
        "jay-babu/mason-null-ls.nvim",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = {
            "williamboman/mason.nvim",
            "nvimtools/none-ls.nvim",
        },
        config = function()
            local null_ls = require("null-ls")
            require("mason-null-ls").setup({
                ensure_installed = { "shfmt" }
            })
            require("null-ls").setup({
                sources = {
                    null_ls.builtins.formatting.shfmt,
                },
            })
        end,
    },
    {
    "neovim/nvim-lspconfig",
    config = function()
        -- Global mappings.
        -- See `:help vim.diagnostic.*` for documentation on any of the below functions
        vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)
        vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next)

        -- Use LspAttach autocommand to only map the following keys
        -- after the language server attaches to the current buffer
        vim.api.nvim_create_autocmd('LspAttach', {
            group = vim.api.nvim_create_augroup('UserLspConfig', {}),
            callback = function(ev)
                -- Enable completion triggered by <c-x><c-o>
                -- vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

                -- Buffer local mappings.
                -- See `:help vim.lsp.*` for documentation on any of the below functions
                local opts = { buffer = ev.buf }

                vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                vim.keymap.set('n', 'gK', vim.lsp.buf.signature_help, opts)
                vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                -- vim.keymap.set('n', 'gD', vim.lsp.buf.definition, opts)
                vim.keymap.set('n', 'gY', vim.lsp.buf.type_definition, opts)
                vim.keymap.set('n', 'gR', vim.lsp.buf.references, opts)
                vim.keymap.set('n', 'gM', vim.lsp.buf.implementation, opts)
                vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
                vim.keymap.set('n', '<space>f', function()
                    vim.lsp.buf.format { async = true }
                end, opts)

                vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
                vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
                vim.keymap.set('n', '<space>wl', function()
                    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                end, opts)

                vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
            end,
        })
        -- When using conda, 'clangd' managed by 'mason-lspconfig' seems buggy.
        -- Manually installation is a work-around: `conda install -c conda-forge clang-tools'
        require 'lspconfig'.clangd.setup {}
    end
    }
}
