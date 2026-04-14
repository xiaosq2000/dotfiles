local enabled = vim.env.KITTY_SCROLLBACK_NVIM ~= "true"

local lsp_servers = {
    { name = "ruff", filetypes = { "python" } },
    { name = "ty", filetypes = { "python" } },
    { name = "lua_ls", filetypes = { "lua" } },
    { name = "bashls", filetypes = { "bash", "sh" } },
    { name = "marksman", filetypes = { "markdown", "markdown.mdx" } },
    { name = "cmake", filetypes = { "cmake" } },
    { name = "dockerls", filetypes = { "dockerfile" } },
    { name = "docker_compose_language_service", filetypes = { "yaml.docker-compose" } },
    { name = "yamlls", filetypes = { "yaml", "yaml.gitlab", "yaml.helm-values" } },
    { name = "jsonls", filetypes = { "json", "jsonc" } },
    { name = "taplo", filetypes = { "toml" } },
}

local mason_packages = {
    "clang-format",
    "latexindent",
    "prettier",
    "shellcheck",
    "shfmt",
    "stylua",
}

local function list_server_names()
    local names = {}
    for _, server in ipairs(lsp_servers) do
        names[#names + 1] = server.name
    end
    return names
end

local function ensure_mason_packages(package_names)
    if #vim.api.nvim_list_uis() == 0 then
        return
    end

    local registry = require("mason-registry")

    registry.refresh(function()
        for _, package_name in ipairs(package_names) do
            local ok, package = pcall(registry.get_package, package_name)
            if ok and not package:is_installed() and not package:is_installing() then
                package:install()
            end
        end
    end)
end

return {
    {
        "mason-org/mason.nvim",
        enabled = enabled,
        config = function()
            require("mason").setup()
            ensure_mason_packages(mason_packages)
        end,
    },
    {
        "mason-org/mason-lspconfig.nvim",
        enabled = enabled,
        dependencies = {
            { "mason-org/mason.nvim", opts = {} },
            "neovim/nvim-lspconfig",
        },
        opts = {
            ensure_installed = list_server_names(),
            automatic_enable = false,
        },
    },
    {
        "neovim/nvim-lspconfig",
        lazy = false,
        enabled = enabled,
        dependencies = { "dnlhc/glance.nvim" },
        config = function()
            vim.api.nvim_create_user_command("LspEnabled", function()
                local lines = {}
                for _, server in ipairs(lsp_servers) do
                    lines[#lines + 1] = ("%s => %s"):format(server.name, table.concat(server.filetypes, ", "))
                end
                vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Enabled LSPs" })
            end, { desc = "List explicitly enabled LSP servers" })

            vim.api.nvim_create_autocmd("LspAttach", {
                group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if client == nil then
                        return
                    end

                    if client.name == "ruff" then
                        -- Prefer Ty for hover and keep Ruff focused on diagnostics/actions.
                        client.server_capabilities.hoverProvider = false
                    end

                    local function map(lhs, rhs, desc)
                        vim.keymap.set("n", lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
                    end

                    map("K", vim.lsp.buf.hover, "LSP hover")
                    map("grd", "<cmd>Glance definitions<cr>", "LSP definitions")
                    map("grr", "<cmd>Glance references<cr>", "LSP references")
                    map("gry", "<cmd>Glance type_definitions<cr>", "LSP type definitions")
                    map("gri", "<cmd>Glance implementations<cr>", "LSP implementations")
                    map("grk", vim.lsp.buf.signature_help, "LSP signature help")
                    map("grD", vim.lsp.buf.declaration, "LSP declaration")
                    map("<leader>wa", vim.lsp.buf.add_workspace_folder, "Workspace add")
                    map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Workspace remove")
                    map("<leader>wl", function()
                        print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
                    end, "Workspace list")
                    map("<leader>li", function()
                        local names = {}
                        for _, attached_client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
                            names[#names + 1] = attached_client.name
                        end

                        local message = #names > 0 and table.concat(names, ", ") or "No LSP clients attached"
                        vim.notify(message, vim.log.levels.INFO, {
                            title = ("LSP clients for %s"):format(vim.bo[args.buf].filetype),
                        })
                    end, "LSP clients")
                end,
                desc = "LSP: buffer-local keymaps",
            })

            for _, server in ipairs(lsp_servers) do
                vim.lsp.enable(server.name)
            end
        end,
        keys = {
            {
                "<space>q",
                vim.diagnostic.setloclist,
                desc = "Set diagnostics in location list",
            },
            {
                "<space>e",
                vim.diagnostic.open_float,
                desc = "Open floating diagnostic window",
            },
            {
                "<space>co",
                ":copen<CR>",
                desc = "Open quickfix window",
            },
            {
                "<space>cx",
                ":cclose<CR>",
                desc = "Close quickfix window",
            },
        },
    },
    {
        "dnlhc/glance.nvim",
        enabled = enabled,
        cmd = "Glance",
    },
    {
        "stevearc/conform.nvim",
        enabled = enabled,
        dependencies = { "mason-org/mason.nvim" },
        opts = {
            default_format_opts = {
                lsp_format = "fallback",
            },
            formatters_by_ft = {
                lua = { "stylua" },
                python = {
                    "ruff_organize_imports",
                    "ruff_fix",
                    "ruff_format",
                },
                cpp = { "clang-format" },
                c = { "clang-format" },
                bash = { "shfmt" },
                sh = { "shfmt" },
                json = { "prettier" },
                jsonc = { "prettier" },
                toml = { "taplo" },
                tex = { "latexindent" },
            },
        },
        keys = {
            {
                "<space>f",
                function()
                    require("conform").format({
                        async = true,
                        timeout_ms = 1000,
                    })
                end,
                desc = "Format buffer",
            },
        },
    },
}
