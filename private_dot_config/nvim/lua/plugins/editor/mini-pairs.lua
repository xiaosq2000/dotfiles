return {
	"echasnovski/mini.pairs",
	version = "*",
	event = "InsertEnter",
	opts = {
		-- Don't auto-pair after ';': it is the LuaSnip autosnippet prefix, and the
		-- auto-inserted closing char would be swallowed by the expanded snippet
		-- (";(" produced "\parens*{)}" instead of "\parens*{}").
		mappings = {
			["("] = { neigh_pattern = "[^\\;]." },
			["["] = { neigh_pattern = "[^\\;]." },
			["{"] = { neigh_pattern = "[^\\;]." },
		},
	},
}
