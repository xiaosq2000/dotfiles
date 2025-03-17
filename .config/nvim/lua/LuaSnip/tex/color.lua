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
	if #parent.snippet.env.LS_SELECT_RAW > 0 then
		return sn(nil, i(1, parent.snippet.env.LS_SELECT_RAW))
	else -- If LS_SELECT_RAW is empty, return a blank insert node
		return sn(nil, i(1))
	end
end

return {
	s({ trig = "tc", dscr = "textcolor" }, fmta("\\textcolor{<>}{<>}", { i(1, "color"), d(2, get_visual) })),
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
	s(
		{ trig = "colors", dscr = "color palette" },
		fmta(
			[[
% \usepackage[dvipsnames]{xcolor}

% official color palette @ university of macau
% https://www.um.edu.mo/about-um/identity/
\definecolor{um-color}{RGB}{0,44,85}
\definecolor{um-blue}{RGB}{0,95,150}
\definecolor{um-gold}{RGB}{210,169,36}
\definecolor{um-green}{RGB}{0,170,148}
\definecolor{um-grey}{RGB}{204,204,204}
\definecolor{um-red}{RGB}{223,41,28}
\definecolor{um-yellow}{RGB}{255,212,70}

% rose-pine palette
% https://rosepinetheme.com/
\definecolor{rosepine-main-base}{HTML}{191724}
\definecolor{rosepine-main-surface}{HTML}{1f1d2e}
\definecolor{rosepine-main-overlay}{HTML}{26233a}
\definecolor{rosepine-main-muted}{HTML}{6e6a86}
\definecolor{rosepine-main-subtle}{HTML}{908caa}
\definecolor{rosepine-main-text}{HTML}{e0def4}
\definecolor{rosepine-main-love}{HTML}{eb6f92}
\definecolor{rosepine-main-gold}{HTML}{f6c177}
\definecolor{rosepine-main-rose}{HTML}{ebbcba}
\definecolor{rosepine-main-pine}{HTML}{31748f}
\definecolor{rosepine-main-foam}{HTML}{9ccfd8}
\definecolor{rosepine-main-iris}{HTML}{c4a7e7}
\definecolor{rosepine-main-highlight-low}{HTML}{21202e}
\definecolor{rosepine-main-highlight-med}{HTML}{403d52}
\definecolor{rosepine-main-highlight-high}{HTML}{524f67}

\definecolor{rosepine-moon-base}{HTML}{232136}
\definecolor{rosepine-moon-surface}{HTML}{2a273f}
\definecolor{rosepine-moon-overlay}{HTML}{393552}
\definecolor{rosepine-moon-muted}{HTML}{6e6a86}
\definecolor{rosepine-moon-subtle}{HTML}{908caa}
\definecolor{rosepine-moon-text}{HTML}{e0def4}
\definecolor{rosepine-moon-love}{HTML}{eb6f92}
\definecolor{rosepine-moon-gold}{HTML}{f6c177}
\definecolor{rosepine-moon-rose}{HTML}{ea9a97}
\definecolor{rosepine-moon-pine}{HTML}{3e8fb0}
\definecolor{rosepine-moon-foam}{HTML}{9ccfd8}
\definecolor{rosepine-moon-iris}{HTML}{c4a7e7}
\definecolor{rosepine-moon-highlight-low}{HTML}{2a283e}
\definecolor{rosepine-moon-highlight-med}{HTML}{44415a}
\definecolor{rosepine-moon-highlight-high}{HTML}{56526e}

\definecolor{rosepine-dawn-base}{HTML}{faf4ed}
\definecolor{rosepine-dawn-surface}{HTML}{fffaf3}
\definecolor{rosepine-dawn-overlay}{HTML}{f2e9e1}
\definecolor{rosepine-dawn-muted}{HTML}{9893a5}
\definecolor{rosepine-dawn-subtle}{HTML}{797593}
\definecolor{rosepine-dawn-text}{HTML}{575279}
\definecolor{rosepine-dawn-love}{HTML}{b4637a}
\definecolor{rosepine-dawn-gold}{HTML}{ea9d34}
\definecolor{rosepine-dawn-rose}{HTML}{d7827e}
\definecolor{rosepine-dawn-pine}{HTML}{286983}
\definecolor{rosepine-dawn-foam}{HTML}{56949f}
\definecolor{rosepine-dawn-iris}{HTML}{907aa9}
\definecolor{rosepine-dawn-highlight-low}{HTML}{f4ede8}
\definecolor{rosepine-dawn-highlight-med}{HTML}{dfdad9}
\definecolor{rosepine-dawn-highlight-high}{HTML}{cecacd}

% rename for convenience for setting beamer theme
\colorlet{color-frametitle}{rosepine-dawn-overlay}
\colorlet{color-progressbar}{rosepine-dawn-gold}

\colorlet{mywhite}{rosepine-dawn-base}
\colorlet{mysubtle}{rosepine-dawn-subtle}
\colorlet{myoverlay}{rosepine-dawn-overlay}
\colorlet{myblack}{rosepine-dawn-text}
\colorlet{mygray}{rosepine-dawn-subtle}
\colorlet{mylightgray}{rosepine-dawn-muted}
\colorlet{myred}{rosepine-dawn-love}
\colorlet{mygold}{rosepine-dawn-gold}
\colorlet{mycyan}{rosepine-dawn-rose}
\colorlet{mygreen}{rosepine-dawn-pine}
\colorlet{myblue}{rosepine-dawn-foam}
\colorlet{mymagenta}{rosepine-dawn-iris}

\definecolorseries{marknode-color-series}{hsb}{last}[hsb]{0.0,0.15,0.95}[hsb]{0.99,0.15,0.95}
\definecolorseries{annotation-color-series}{hsb}{last}[hsb]{0.0,0.8,0.65}[hsb]{0.99,0.8,0.65}
\resetcolorseries[12]{marknode-color-series}
\resetcolorseries[12]{annotation-color-series}
    ]],
			{}
		)
	),
}
