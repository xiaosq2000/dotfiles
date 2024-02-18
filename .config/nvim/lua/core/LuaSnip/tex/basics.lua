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
    --------------------------------------------------------------------------------
    ------------------------------------ fonts -------------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "tit" },
        fmta("\\textit{<>}", { d(1, get_visual) })
    ),
    s({ trig = "tbf" },
        fmta("\\textbf{<>}", { d(1, get_visual) })
    ),
    s({ trig = "ttt" },
        fmta("\\texttt{<>}", { d(1, get_visual) })
    ),
    s({ trig = "tsf" },
        fmta("\\textsf{<>}", { d(1, get_visual) })
    ),
    s({ trig = "trm" },
        fmta("\\textrm{<>}", { d(1, get_visual) })
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- spacing ------------------------------------
    --------------------------------------------------------------------------------
    s({ trig = ";hf", snippetType = "autosnippet" },
        t("\\hspace*{\\fill}", {})
    ),
    s({ trig = ";vf", snippetType = "autosnippet" },
        t("\\vspace*{\\fill}", {})
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- brackets -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = ";(", snippetType = "autosnippet" }, fmta("\\left(<>\\right)", { d(1, get_visual) })),
    s({ trig = ";[", snippetType = "autosnippet" }, fmta("\\left[<>\\right]", { d(1, get_visual) })),
    s({ trig = ";{", snippetType = "autosnippet" }, fmta("\\left\\{<>\\right\\}", { d(1, get_visual) })),
}
