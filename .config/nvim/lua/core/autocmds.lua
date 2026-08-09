local augroup = function(name)
	return vim.api.nvim_create_augroup("user." .. name, { clear = true })
end

-- Create missing parent directories for ordinary files. URI-backed buffers
-- (for example suda://) own their write path and must not be treated as local
-- filesystem paths.
vim.api.nvim_create_autocmd("BufWritePre", {
	group = augroup("auto_mkdir"),
	callback = function(args)
		if vim.bo[args.buf].buftype ~= "" then
			return
		end

		local file = vim.api.nvim_buf_get_name(args.buf)
		if file == "" or file:match("^%a[%w+.-]*://") then
			return
		end

		local parent = vim.fs.dirname(file)
		if parent and vim.uv.fs_stat(parent) == nil then
			vim.fn.mkdir(parent, "p")
		end
	end,
	desc = "Create missing parent directories before writing",
})

-- Restore the cursor from ShaDa when reopening a normal file.
vim.api.nvim_create_autocmd("BufReadPost", {
	group = augroup("last_position"),
	callback = function(args)
		if vim.bo[args.buf].buftype ~= "" then
			return
		end
		if
			vim.list_contains({ "gitcommit", "gitrebase" }, vim.bo[args.buf].filetype)
		then
			return
		end

		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		if mark[1] <= 0 or mark[1] > vim.api.nvim_buf_line_count(args.buf) then
			return
		end

		local win = vim.fn.bufwinid(args.buf)
		if win == -1 then
			return
		end
		vim.api.nvim_win_set_cursor(win, mark)
		vim.api.nvim_win_call(win, function()
			vim.cmd.normal({ "zv", bang = true })
		end)
	end,
	desc = "Restore the last cursor position",
})

-- Strip gutter decorations from the experimental message UI's scratch windows.
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("message_ui"),
	pattern = { "cmd", "msg", "pager", "dialog" },
	callback = function()
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
		vim.opt_local.foldcolumn = "0"
		vim.opt_local.colorcolumn = ""
	end,
})

-- Prose filetypes indent two-wide; prettier and tex-fmt are configured to match.
vim.api.nvim_create_autocmd("FileType", {
	group = augroup("prose_indent"),
	pattern = { "markdown", "tex" },
	callback = function()
		vim.opt_local.tabstop = 2
		vim.opt_local.softtabstop = 2
		vim.opt_local.shiftwidth = 2
		vim.opt_local.expandtab = true
	end,
})
