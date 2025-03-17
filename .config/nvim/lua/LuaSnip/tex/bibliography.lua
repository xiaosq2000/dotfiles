local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

return {
	s(
		{ trig = "biblatex", dscr = "" },
		fmta(
			[[
            \usepackage[backend=biber,natbib=true,style=<>]{biblatex}
            \addbibresource{<>}
            \renewcommand*{\bibfont}{\normalfont\small}
        ]],
			{ i(1, "ieee"), i(2, "references.bib") }
		)
	),
}
