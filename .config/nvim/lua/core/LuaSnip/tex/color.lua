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

local get_visual = function(args, parent)
    if (#parent.snippet.env.LS_SELECT_RAW > 0) then
        return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
    else -- If LS_SELECT_RAW is empty, return a blank insert node
        return sn(nil, i(1))
    end
end

return {
    s({ trig = "preamble-color" },
        fmta(
            [[
% \usepackage[dvipsnames]{xcolor}
\definecolorseries{marknode-color-series}{hsb}{last}[hsb]{0.0,0.15,0.95}[hsb]{0.99,0.15,0.95}
\definecolorseries{annotation-color-series}{hsb}{last}[hsb]{0.0,0.8,0.65}[hsb]{0.99,0.8,0.65}
\resetcolorseries[12]{marknode-color-series}
\resetcolorseries[12]{annotation-color-series}
    ]], {}
        )
    ),
    s({ trig = "tc" },
        fmta("\\textcolor{<>}{<>}", { i(1, "color"), d(2, get_visual) })
    ),
}
