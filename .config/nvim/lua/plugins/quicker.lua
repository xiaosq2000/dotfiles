-- Improved UI and workflow for the Neovim quickfix
return {
    'stevearc/quicker.nvim',
    enabled = true,
    event = "FileType qf",
    ---@module "quicker"
    ---@type quicker.SetupOptions
    opts = {},
}
