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
    s({ trig = "xcolor" },
        fmta(
            [[
        \usepackage{xcolor}
            % ref: http://zhongguose.com
            \definecolor{kongquelan}{RGB}{14,176,201}
            \definecolor{koushaolv}{RGB}{93,190,138}
            \definecolor{yingwulv}{RGB}{91,174,35}
            \definecolor{shenhuilan}{RGB}{19,44,51}
            \definecolor{jianniaolan}{RGB}{20,145,168}
            \definecolor{jiguanghong}{RGB}{243,59,31}
            \definecolor{xiangyehong}{RGB}{240,124,130}
    ]], {}
        )
    ),
    s({ trig = "tc" },
        fmta("\\textcolor{<>}{<>}", { i(1, "color"), d(2, get_visual) })
    ),
}
