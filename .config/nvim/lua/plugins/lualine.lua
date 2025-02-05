return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'rose-pine/neovim' },
    config = function()
        vim.schedule(function()
            -- Get rose-pine's palette
            local colors = require('rose-pine.palette')
            local theme = {
                normal = {
                    a = { fg = colors.rose, bg = colors.overlay, gui = 'bold' },
                    b = { fg = colors.subtle, bg = colors.overlay, gui = 'bold' },
                    c = { fg = colors.text, bg = colors.overlay },
                    x = { fg = colors.text, bg = colors.overlay },
                    y = { fg = colors.text, bg = colors.overlay },
                    z = { fg = colors.text, bg = colors.overlay },
                },
                insert = {
                    a = { fg = colors.pine, bg = colors.overlay, gui = 'bold' },
                    b = { fg = colors.subtle, bg = colors.overlay, gui = 'bold' },
                    c = { fg = colors.text, bg = colors.overlay },
                    x = { fg = colors.text, bg = colors.overlay },
                    y = { fg = colors.text, bg = colors.overlay },
                    z = { fg = colors.text, bg = colors.overlay },
                },
                visual = {
                    a = { fg = colors.love, bg = colors.overlay, gui = 'bold' },
                    b = { fg = colors.subtle, bg = colors.overlay, gui = 'bold' },
                    c = { fg = colors.text, bg = colors.overlay },
                    x = { fg = colors.text, bg = colors.overlay },
                    y = { fg = colors.text, bg = colors.overlay },
                    z = { fg = colors.text, bg = colors.overlay },
                },
                command = {
                    a = { fg = colors.gold, bg = colors.overlay, gui = 'bold' },
                    b = { fg = colors.subtle, bg = colors.overlay, gui = 'bold' },
                    c = { fg = colors.text, bg = colors.overlay },
                    x = { fg = colors.text, bg = colors.overlay },
                    y = { fg = colors.text, bg = colors.overlay },
                    z = { fg = colors.text, bg = colors.overlay },
                },
                replace = {
                    a = { fg = colors.iris, bg = colors.overlay, gui = 'bold' },
                    b = { fg = colors.subtle, bg = colors.overlay, gui = 'bold' },
                    c = { fg = colors.text, bg = colors.overlay },
                    x = { fg = colors.text, bg = colors.overlay },
                    y = { fg = colors.text, bg = colors.overlay },
                    z = { fg = colors.text, bg = colors.overlay },
                },
            }
            local empty = require('lualine.component'):extend()
            function empty:draw(default_highlight)
                self.status = ''
                self.applied_separator = ''
                self:apply_highlights(default_highlight)
                self:apply_section_separators()
                return self.status
            end

            -- Put proper separators and gaps between components in sections
            local function process_sections(sections)
                for name, section in pairs(sections) do
                    local left = name:sub(9, 10) < 'x'
                    for pos = 1, name ~= 'lualine_z' and #section or #section - 1 do
                        table.insert(section, pos * 2, { empty, color = { fg = colors.base, bg = colors.base } })
                    end
                    for id, comp in ipairs(section) do
                        if type(comp) ~= 'table' then
                            comp = { comp }
                            section[id] = comp
                        end
                        comp.separator = left and { right = '' } or { left = '' }
                    end
                end
                return sections
            end

            local function search_result()
                if vim.v.hlsearch == 0 then
                    return ''
                end
                local last_search = vim.fn.getreg('/')
                if not last_search or last_search == '' then
                    return ''
                end
                local searchcount = vim.fn.searchcount { maxcount = 9999 }
                return last_search .. '(' .. searchcount.current .. '/' .. searchcount.total .. ')'
            end

            local function modified()
                if vim.bo.modified then
                    return '+'
                elseif vim.bo.modifiable == false or vim.bo.readonly == true then
                    return '-'
                end
                return ''
            end

            require('lualine').setup {
                options = {
                    theme = theme,
                    component_separators = '',
                    section_separators = { left = '', right = '' },
                },
                sections = process_sections {
                    lualine_a = {
                        { 'mode' },
                        { modified, color = { fg = colors.rose, bg = colors.overlay } },
                    },
                    lualine_b = {
                        {
                            'diagnostics',
                            source = { 'nvim' },
                            sections = { 'error' },
                            diagnostics_color = { error = { bg = colors.gold, fg = colors.text } },
                        },
                        {
                            'diagnostics',
                            source = { 'nvim' },
                            sections = { 'warn' },
                            diagnostics_color = { warn = { bg = colors.gold, fg = colors.text } },
                        },
                    },
                    lualine_c = {
                        -- 'branch',
                        -- 'diff',
                        {
                            '%w',
                            cond = function()
                                return vim.wo.previewwindow
                            end,
                        },
                        {
                            '%r',
                            cond = function()
                                return vim.bo.readonly
                            end,
                        },
                        {
                            '%q',
                            cond = function()
                                return vim.bo.buftype == 'quickfix'
                            end,
                        },
                    },
                    lualine_x = { '%p%%(%l/%L), %c' },
                    lualine_y = { { 'filename', file_status = false, path = 1 }, },
                    lualine_z = { search_result, 'filetype' },
                },
                inactive_sections = {
                    lualine_c = { '%f %y %m' },
                    lualine_x = {},
                },
            }
        end)
    end
}
