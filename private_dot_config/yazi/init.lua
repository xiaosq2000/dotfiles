-- ~/.config/yazi/init.lua
require("bookmarks"):setup({
	-- https://github.com/dedukun/bookmarks.yazi
	last_directory = { enable = false, persist = false, mode = "dir" },
	persist = "vim",
	desc_format = "parent",
	file_pick_mode = "hover",
	custom_desc_input = false,
	notify = {
		enable = true,
		timeout = 1,
		message = {
			new = "New bookmark '<key>' -> '<folder>'",
			delete = "Deleted bookmark in '<key>'",
			delete_all = "Deleted all bookmarks",
		},
	},
})
