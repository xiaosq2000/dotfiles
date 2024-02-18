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
    s({ trig = "beamer" },
        fmta(
            [[
\documentclass[utf-8, 10pt, aspectratio=1610]{beamer}
\mode<<presentation>>
\usetheme[
    background=light,
    titleformat=regular,
    subsectionpage=progressbar,
    block=fill,
]{metropolis}
\usepackage{appendixnumberbeamer}
    ]], {}
        )
    )
}
