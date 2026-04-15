return {
    "OXY2DEV/markview.nvim",
    lazy = false,
    dependencies = { "saghen/blink.cmp" },
    init = function()
        vim.api.nvim_create_autocmd("FileType", {
            pattern = "markdown",
            callback = function()
                vim.opt_local.wrap = false
            end,
        })
    end,
};
