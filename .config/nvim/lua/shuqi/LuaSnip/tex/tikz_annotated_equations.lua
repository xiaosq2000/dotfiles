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
    s({ trig = "tikz_annotated_equations", dscr = "ref: https://github.com/synercys/annotated_latex_equations" },
        fmta([[
        \usepackage{tikz}
        \usetikzlibrary{calc,tikzmark}
        \usepackage{tcolorbox}
        \colorlet{marknode_color}{cyan!30}
        \colorlet{annotate_color}{cyan!60}
    ]]
        , {})
    ),
    s({ trig = "tikz_picture" },
        fmta(
            [[
        \begin{tikzpicture}[overlay,remember picture,>>=stealth,nodes={align=left,inner ysep=1pt},<<-]
            <>
        \end{tikzpicture}
    ]],
            { i(1, "put tikz annotate here") }
        )
    ),
    s({ trig = "tikz_marknode" },
        fmta(
            [[
        \tikzmarknode{<>}{\colorbox{<>}{\(<>\)}}
    ]],
            { i(2, "marknode name"), i(3, "color name"), d(1, get_visual) }
        )
    ),
    -- Todo: make it a choice node
    s({ trig = "tikz_annotate" },
        fmta(
            [[
        \path (<>.<>) ++ (<>em,<>em) node[anchor=<>,color=<>] (<>_annotate) {\footnotesize{<>}};
        \draw [color=<>] (<>.<>) |- (<>_annotate.<>);
    ]],
            { i(1, "marknode name"), i(2, "marknode direction"), i(3, "0"), i(4, "0"), i(5, "anchor direction"),
                i(6, "color name"), rep(1), i(8, "put annotate here"), rep(6), rep(1), rep(2), rep(1),
                i(7, "arrow annotate direction") }
        )
    ),
}
