-- Improved UI and workflow for the Neovim quickfix
return {
    'stevearc/quicker.nvim',
    enabled = false,
    event = "FileType qf",
    ---@module "quicker"
    ---@type quicker.SetupOptions
    opts = {},
}
