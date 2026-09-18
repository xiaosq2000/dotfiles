-- Motions based on indent depth, in normal, visual and operator-pending modes.
--   [- / ]-  previous / next line of lesser indent
--   [+ / ]+  previous / next line of greater indent
--   [= / ]=  previous / next line of the same indent, across a differing block
--   [% / ]%  beginning / end of the indent-block scope
-- All of the above take a {count}.
return {
	"jeetsukumaran/vim-indentwise",
	keys = {
		{ "[-", mode = { "n", "v", "o" } },
		{ "[+", mode = { "n", "v", "o" } },
		{ "[=", mode = { "n", "v", "o" } },
		{ "]-", mode = { "n", "v", "o" } },
		{ "]+", mode = { "n", "v", "o" } },
		{ "]=", mode = { "n", "v", "o" } },
		{ "[%", mode = { "n", "v", "o" } },
		{ "]%", mode = { "n", "v", "o" } },
	},
}
