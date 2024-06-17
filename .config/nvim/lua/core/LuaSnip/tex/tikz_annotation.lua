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
    s(
        { trig = "tikz_equation_annotation_preamble", dscr = "ref: https://github.com/synercys/annotated_latex_equations" },
        fmta([[
        \usepackage{tikz}
        \usetikzlibrary{calc,tikzmark}
        \usepackage{tcolorbox}
        \usepackage{makecell}
    ]]
        , {})
    ),
    s({ trig = "tikz_equation_annotation_environment" },
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
    -- TODO: make it a choice node
    s({ trig = "tikz_equation_annotation" },
        fmta(
            [[
        \path (<>.<>) ++ (<>em,<>em) node[anchor=<>,color=<>] (<>_annotate) { \scriptsize \makecell[l]{<>} };
        \draw [color=<>] (<>.<>) |- (<>_annotate.<>);
    ]],
            { i(1, "marknode name"), i(2, "marknode direction"), i(3, "0"), i(4, "0"), i(5, "anchor direction"),
                i(6, "color name"), rep(1), i(8, "put annotate here"), rep(6), rep(1), rep(2), rep(1),
                i(7, "arrow annotate direction") }
        )
    ),
    s({ trig = "tikz_figure_annotation" },
        fmta([[
        \begin{annotatedFigure}
        {\includegraphics[width=0.5\linewidth]{<>}}
        \annotatedFigureBox{<>}{<>}{<>}{<>}
        \end{annotatedFigure}
    ]], { i(1, "figure-path"), i(2, "bottom-left"), i(3, "top-right"), i(4, "label"), i(5, "label-position") })
    ),
    s({ trig = "tikz_timeline" },
        fmta([[
    \begin{tikzpicture}
		\usetikzlibrary{calc}

		\pgfmathsetmacro{\dy}{0.3cm/1pt};
		\pgfmathsetmacro{\nodeNum}{4};
		\pgfmathsetmacro{\sepNum}{\nodeNum-1};
		\pgfmathsetmacro{\length}{0.8*\linewidth};
		\pgfmathsetmacro{\edgeLength}{1cm/1pt};
		\pgfmathsetmacro{\dx}{(\length-\edgeLength-\edgeLength)/\sepNum};
		\pgfmathsetmacro{\xShift}{0};

		\tikzset{
			note/.style={
					anchor=north, align=center, text width=\dx, yshift=-\dy/3, font={\scriptsize}
				},
			time/.style={
					anchor=south, font={\scriptsize\bf}
				}
		};

		\coordinate (start) at (0 pt,0 pt);
		\coordinate (end) at (\length pt,0 pt);
		\draw [line width=1.5pt,-stealth] (start) -- (end);

		\foreach \counter in {0,...,\sepNum} {
				\coordinate (s\counter) at (\edgeLength+\counter*\dx pt,0);
				\coordinate (t\counter) at ($(s\counter)+(0,\dy pt)$);
				\draw [line width=1.5pt] (s\counter) -- (t\counter);
			}

		\node [time] at (t0.north) {
			11/2023 - 12/2024
		};
		\node [note] at (s0.south) {
			(CVPR) LEGS \\[1ex]
			(CVPR) LangSplat\\[1ex]
			(CVPR) Feature 3DGS\\[1ex]
			Segment Any Gaussian\\[1ex]
			Gaussian Grouping
		};
		\node [time] at (t1.north) {
			01/2024 - 04/2024
		};
		\node [note] at (s1.south) {
			CoSSegGaussians\\[1ex]
			Semantic Gaussians\\[1ex]
			Feature Splating\\[1ex]
			CLIP-GS
		};
		\node [time] at (t2.north) {
			05/2024 - 06/2024
		};
		\node [note] at (s2.south) {
			GOI\\[1ex]
			RT-GS2\\[1ex]
			SA-GS\\[1ex]
			Fast-LGS
		};
	\end{tikzpicture}

    ]], {})
    ),
}
