-- Read and write root-owned files over sudo.
return {
	"lambdalisue/vim-suda",
	event = { "BufReadPre", "BufNewFile" },
	cmd = { "SudaRead", "SudaWrite" },
	init = function()
		vim.g.suda_smart_edit = 1
	end,
}
