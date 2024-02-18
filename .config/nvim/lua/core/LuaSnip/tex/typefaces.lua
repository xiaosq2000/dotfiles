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
    s({ trig = "typefaces" },
        fmta([[
\usepackage{fontawesome5}
\usepackage[no-math]{fontspec}
    \setmainfont{Source Serif 4}
    \setsansfont{Source Sans 3}
    \setmonofont{Source Code Pro}
\usepackage{xeCJK}
    \setCJKmainfont{思源宋体}
    \setCJKsansfont{思源黑体}
    \setCJKmonofont{思源等宽}
    ]], {}
        )
    )
}
