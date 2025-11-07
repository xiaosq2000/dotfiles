local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local c = ls.choice_node
local fmt = require("luasnip.extras.fmt").fmt
local fmta = require("luasnip.extras.fmt").fmta
local rep = require("luasnip.extras").rep

local get_visual = function(args, parent)
	if #parent.snippet.env.LS_SELECT_RAW > 0 then
		return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
	else -- If LS_SELECT_RAW is empty, return a blank insert node
		return sn(nil, i(1))
	end
end

return {
	s(
		{ trig = "tc", dscr = "textcolor" },
		fmta("\\textcolor{<>}{<>}", {
			c(1, { t("color-primary"), t("color-secondary") }),
			d(2, get_visual),
		})
	),
	s(
		{ trig = "rc", dscr = "resetcolorseries" },
		fmta(
			[[
\resetcolorseries[<>]{marknode-color-series}
\resetcolorseries[<>]{annotation-color-series}
        ]],
			{ i(1, "4"), rep(1) }
		)
	),
}
