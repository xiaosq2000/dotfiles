local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
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
    ----------------------------- equation annotation ------------------------------
    --------------------------------------------------------------------------------
    s(
        { trig = "preamble-equation-annotation", dscr = "ref: https://github.com/synercys/annotated_latex_equations" },
        fmta([[
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%% equation annotation by TikZ %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{tikz}
% \usepackage[dvipsnames]{xcolor}
\usetikzlibrary{calc,tikzmark}
% \usepackage{tcolorbox}
\usepackage{makecell}
\usepackage{xstring}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Usage:
% \annotatedEquation{1: color/colorseries}{2: node name}{3: node direction}{4: x shift}{5: y shift}{6: anchor direction}{7: color/colorseries name}{8: annotation}{9: baseline direction}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\newenvironment{annotatedEquationEnv}{
    \begin{tikzpicture}[
        overlay, remember picture,
        >>=stealth, <<-,
        nodes={align=left,inner ysep=1pt},
    ]
}
{
    \end{tikzpicture}
}
\newcommand*{\annotatedEquation}[9]{%
     \IfEqCase{#1}{%
        {color}{%
            \path (#2.#3) ++ (#4,#5) node [anchor=#6] (#2-annotate) { \color{#7} \scriptsize \makecell[l]{#8} };%
            \draw [#7] (#2.#3) |- (#2-annotate.south #9);%
        }%
        {colorseries}{%
            \path (#2.#3) ++ (#4,#5) node [anchor=#6] (#2-annotate) { \color{#7!!} \scriptsize \makecell[l]{#8} };%
            \draw [#7!!] (#2.#3) |- (#2-annotate.south #9);%
            \textcolor{#7!!+}{}%
        }%
    }[\PackageError{annotatedEquation}{Undefined option to annotatedEquation #1}{}]%
}%
    ]]
        , {})
    ),
    s({ trig = "env-equation-annotation" },
        fmta(
            [[
\begin{annotatedEquationEnv}
    <>
\end{annotatedEquationEnv}
    ]],
            { i(1, "Use \\annotatedEquation here.") }
        )
    ),
    s({ trig = "tikzmarknode" },
        fmta(
            [[
\tikzmarknode{n<>}{\colorbox{marknode-color-series!![<>]}{\(<>\)}}
    ]],
            { i(1, "0"), rep(1), d(2, get_visual) }
        )
    ),
    s({ trig = "tikzmarknode-beamer-overlay" },
        fmta(
            [[
\alt<<<>>>{\tikzmarknode{n<>}{\colorbox{marknode-color-series!![<>]}{\(<>\)}}}{<>}
     ]],
            { i(1, "+(1)-"), i(2, "0"), rep(2), d(3, get_visual), rep(3) }
        )
    ),
    s({ trig = "equation-annotation" },
        fmta(
            [[
\annotatedEquation{<>}{n<>}{<>}{0em}{<>em}{<>}{<>}{<>}{<>}
    ]],
            { c(1, { t("colorseries"), t("color") }), i(2, "0"), c(3, { t("south"), t("north") }), i(4,
                "-0.5"), c(5, { t("north west"), t("north east"), t("south west"), t("south east") }),
                i(6, "annotation-color-series"), i(7, "annotation"), c(8, { t("east"), t("west") }) }
        )
    ),
    s({ trig = "equation-annotation-beamer-overlay" },
        fmta(
            [[
\only<<<>>>{\annotatedEquation{color}{n<>}{<>}{0em}{<>em}{<>}{annotation-color-series!![<>]}{<>}{<>}}
    ]],
            { i(1, "+(1)-"), i(2, "0"), c(3, { t("south"), t("north") }), i(4,
                "-0.5"), c(5, { t("north west"), t("north east"), t("south west"), t("south east") }),
                rep(2),
                i(6, "annotation"), c(7, { t("east"), t("west") }) }
        )
    ),
    --------------------------------------------------------------------------------
    ------------------------------ figure annotation -------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "preamble-figure-annotation" },
        fmta([[
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%% figure annotation by TikZ  %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{tikz}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Usage:
% \begin{annotatedFigureEnv}
%     {\includegraphics[width=0.5\linewidth]{example-image}}
%     \annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
% \end{annotatedFigureEnv}
% Usage:
% \annotatedFigure{bottom-left}{top-right}{label}{label-position}
% Usage:
% \annotatedFigureImpl{1: bottom-left}{2: top-right}{3: label}{4: label-position}{5: box-color}{6: label-color}{7: border-color}{8: text-color}
% Usage:
% \figureBox{bottom-left}{top-right}{color}{thickness}
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\newcommand*\annotatedFigureImpl[8]{
    \draw [#5, ultra thick] (#1) rectangle (#2);
    \node at (#4) [fill=#6, thick, shape=rectangle, draw=#7, inner sep=2.5pt, font=\small\sffamily, text=#8] { #3 };
}
\newcommand*\annotatedFigure[4]{
    \annotatedFigureImpl{#1}{#2}{#3}{#4}{color-progressbar}{color-progressbar}{color-progressbar}{black!2}
}
\newcommand*\annotatedFigureText[4]{
    \node[draw=none, anchor=south west, text=#2, inner sep=0, text width=#3\linewidth,font=\sffamily] at (#1) {#4};
}
\newenvironment{annotatedFigureEnv}[1]{
    \centering
    \begin{tikzpicture}
        \node[anchor=south west,inner sep=0] (image) at (0,0) { #1 };
        \begin{scope}[x={(image.south east)},y={(image.north west)}]
}
{
        \end{scope}
    \end{tikzpicture}
}
\newcommand*\figureBox[4]{\draw[#3,#4,rounded corners] (#1) rectangle (#2);}
    ]], {})
    ),
    s({ trig = "env-figure-annotation" },
        fmta([[
\begin{annotatedFigureEnv}
    {\includegraphics[width=0.5\linewidth]{<>}}
    <>
\end{annotatedFigureEnv}
    ]], { i(1, "example-image"), i(2, "figure-annotation") })
    ),
    s({ trig = "figure-annotation", desr = "bottom-left, top-right, label, label-position" },
        fmta([[
\annotatedFigure{<>}{<>}{<>}{<>}
    ]], { i(1, "0,0"), i(2, "1,1"), i(3, "annotation"), rep(1) })
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- timeline -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "timeline-example" },
        fmta([[
    \begin{tikzpicture}
		\usetikzlibrary{calc}

		\pgfmathsetmacro{\dy}{0.3cm/1pt};
		\pgfmathsetmacro{\nodeNum}{3};
		\pgfmathsetmacro{\sepNum}{\nodeNum-1};
		\pgfmathsetmacro{\length}{0.8*\linewidth};
		\pgfmathsetmacro{\edgeLength}{1cm/1pt};
		\pgfmathsetmacro{\dx}{(\length-\edgeLength-\edgeLength)/\sepNum};
		\pgfmathsetmacro{\xShift}{0};

		\tikzset{
			note/.style={
					anchor=north, align=center, text width=\dx, yshift=-\dy/3, font={\scriptsize}, text=black
				},
			time/.style={
					anchor=south, font={\scriptsize\bf}, text=black
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
    --------------------------------------------------------------------------------
    ---------------------------------- help grid -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "tikz-help-grid" },
        fmta([[
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% tikz help grid %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Reference: https://tex.stackexchange.com/a/39698/240783
% Usage:
%     \draw (-2,-2) to [grid with coordinates] (7,4);
\makeatletter
\def\grd@save@target#1{%
    \def\grd@target{#1}}
\def\grd@save@start#1{%
    \def\grd@start{#1}}
\tikzset{
    grid with coordinates/.style={
            to path={%
                    \pgfextra{%
                        \edef\grd@@target{(\tikztotarget)}%
                        \tikz@scan@one@point\grd@save@target\grd@@target\relax
                        \edef\grd@@start{(\tikztostart)}%
                        \tikz@scan@one@point\grd@save@start\grd@@start\relax
                        \draw[minor help lines] (\tikztostart) grid (\tikztotarget);
                        \draw[major help lines] (\tikztostart) grid (\tikztotarget);
                        \grd@start
                        \pgfmathsetmacro{\grd@xa}{\the\pgf@x/1cm}
                        \pgfmathsetmacro{\grd@ya}{\the\pgf@y/1cm}
                        \grd@target
                        \pgfmathsetmacro{\grd@xb}{\the\pgf@x/1cm}
                        \pgfmathsetmacro{\grd@yb}{\the\pgf@y/1cm}
                        \pgfmathsetmacro{\grd@xc}{\grd@xa + \pgfkeysvalueof{/tikz/grid with coordinates/major step}}
                        \pgfmathsetmacro{\grd@yc}{\grd@ya + \pgfkeysvalueof{/tikz/grid with coordinates/major step}}
                        \foreach \x in {\grd@xa,\grd@xc,...,\grd@xb}
                        \node[anchor=north] at (\x,\grd@ya) {\pgfmathprintnumber{\x}};
                        \foreach \y in {\grd@ya,\grd@yc,...,\grd@yb}
                        \node[anchor=east] at (\grd@xa,\y) {\pgfmathprintnumber{\y}};
                    }
                }
        },
    minor help lines/.style={
            help lines,
            step=\pgfkeysvalueof{/tikz/grid with coordinates/minor step}
        },
    major help lines/.style={
            help lines,
            line width=\pgfkeysvalueof{/tikz/grid with coordinates/major line width},
            step=\pgfkeysvalueof{/tikz/grid with coordinates/major step}
        },
    grid with coordinates/.cd,
    minor step/.initial=.2,
    major step/.initial=1,
    major line width/.initial=2pt,
}
\makeatother
    ]], {})
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- mindmap  -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "example-mindmap" },
        fmta([[
\resizebox{!}{0.7\textheight}{
    \begin{tikzpicture}
        \usetikzlibrary{mindmap}
        \colorlet{0_color_mindmap}{violet}
        \colorlet{1_color_mindmap}{teal}
        \colorlet{2_color_mindmap}{Salmon}
        \colorlet{3_color_mindmap}{olive}
        \path[
            mindmap,
            every node/.style={concept},
            grow cyclic,
            root concept/.append style={
                    concept color=black,
                    font=\Huge\bfseries,
                    text width=15em,
                },
            level 1 concept/.append style={
                    font=\huge\bfseries,
                    text width=12em,
                    sibling angle=360/4,
                    rotate=45,
                    level distance=20em,
                },
            level 2 concept/.append style={
                    font=\Large\bfseries,
                    level distance=15em,
                },
            level 3 concept/.append style={
                    font=\large\bfseries,
                },
            text=white,
        ]
        node[root concept] {Semantic\\[1ex]NeRF/3DGS} [clockwise from=-90] {
            child[concept color=0_color_mindmap] {
                    node[concept] {Accuracy} [counterclockwise from=180] {
                            % child {node[concept] {1}}
                            % child {node[concept] {2}}
                            % child {node[concept] {3}}
                            % child {node[concept] {4}}
                        }
                }
            child[concept color=1_color_mindmap] {
                    node[concept] {Efficiency} [counterclockwise from=90] {
                            % child {node[concept] {1}}
                            % child {node[concept] {2}}
                            % child {node[concept] {3}}
                            % child {node[concept] {4}}
                        }
                }
            child[concept color=2_color_mindmap] {
                    node[concept] {Consistency} [counterclockwise from=0] {
                            % child {node[concept] {1}}
                            % child {node[concept] {2}}
                            % child {node[concept] {3}}
                            % child {node[concept] {4}}
                        }
                }
            child[concept color=3_color_mindmap] {
                    node[concept] {Interactivity} [counterclockwise from=-90] {
                            % child {node[concept] {1}}
                            % child {node[concept] {2}}
                            % child {node[concept] {3}}
                            % child {node[concept] {4}}
                        }
                }
        };
    \end{tikzpicture}
}
    ]], {})
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- taxonomy -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "preamble-taxonomy" },
        fmta([[
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Taxonomy by TikZ %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ref: https://tex.stackexchange.com/a/112471/240783
% ref: https://tex.stackexchange.com/a/357412/240783
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usetikzlibrary{shadows}
\makeatletter
\def\tikzopacityregister{.2} % the opacity of the shadows
\tikzset{
  opacity/.append code={
    \pgfmathsetmacro\tikzopacityregister{#1*\tikzopacityregister}
  },
  opacity aux/.code={ % this is the original definition of opacity
    \tikz@addoption{\pgfsetstrokeopacity{#1}\pgfsetfillopacity{#1}}
  },
  every shadow/.style={opacity aux=\tikzopacityregister}
}
\makeatother
\tikzset{
    my node for tree/.style={
            text=black,
            draw=lightgray!50,
            fill=lightgray!20,
            % inner color=lightgray!5,
            % outer color=lightgray!20,
            thick,
            minimum width=12mm,
            minimum height=6mm,
            rounded corners=3,
            text height=1.5ex,
            text depth=0ex,
            font={\sffamily},
            drop shadow,
        },
    invisible/.style={opacity=0,text opacity=0},
    visible on/.style={alt=#1{}{invisible}},
    alt/.code args={<<#1>>#2#3}{%
      \alt<<#1>>{\pgfkeysalso{#2}}{\pgfkeysalso{#3}} % \pgfkeysalso doesn't change the path
    },
}
\forestset{
    visible on/.style={
        for tree={
            /tikz/visible on={#1},
            edge+={/tikz/visible on={#1}},
        }
    },
    my tree/.style={
            my node for tree,
            s sep+=4pt,
            l sep+=10pt,
            grow'=east,
            edge+={lightgray},
            parent anchor=east,
            child anchor=west,
            edge path={
                    \noexpand\path [draw, \forestoption{edge}] (!u.parent anchor) -- +(10pt,0) |- (.child anchor)\forestoption{edge label};
                },
            if={isodd(n_children())}{
                    for children={
                            if={equal(n,(n_children("!u")+1)/2)}{calign with current}{}
                        }
                }{},
        }
}
        ]], {})
    ),
    s({ trig = "example-taxonomy" },
        fmta([[
\tikzset{
    key/.style={
            draw=OrangeRed,
        },
    convention/.style={
            draw=Cyan,
        },
    trick/.style={
            draw=YellowGreen,
        },
}
\resizebox{0.85\textwidth}{!}{
    \begin{forest}
        for tree={my tree}
        [
        MonoGS
            [
                Visual Odometry,for children={visible on=<<1->>}
                    [
                        Tracking,for children={visible on=<<2->>}
                            [
                                Inverse Rendering,font=\bf,for children={visible on=<<3->>}
                                    [
                                        Analytical Jacobians Derivation,key
                                    ]
                                    [
                                        Photometric Appearance \& Depth Loss,convention
                                    ]
                                    [
                                        Optimizable Exposure,trick
                                    ]
                                    [
                                        Pixel-wise Penalization,trick
                                    ]
                            ]
                    ]
                    [
                        Mapping,for children={visible on=<<2->>}
                            [
                                Bundle Adjustment,font=\bf,for children={visible on=<<3->>}
                                    [
                                        Photometric Appearance \& Depth Loss,convention
                                    ]
                                    [
                                        Isotropic Regularization,key
                                    ]
                                    [
                                        Random Recall,trick
                                    ]
                            ]
                    ]
            ]
            [
                Online Pipeline,for children={visible on=<<1->>}
                    [
                        Keyframe Management,for children={visible on=<<2->>}
                            [
                                Registration,for children={visible on=<<3->>}
                                    [
                                        Gaussian Covisibility,key
                                    ]
                                    [
                                        Relative Translation,convention
                                    ]
                            ]
                            [
                                Removal,for children={visible on=<<3->>}
                                    [
                                        Gaussian Overlap Coefficient,key
                                    ]
                            ]
                    ]
                    [
                        Gaussian Management,for children={visible on=<<2->>}
                            [
                                Insertion,for children={visible on=<<3->>}
                                    [
                                        Keyframing,convention
                                    ]
                            ]
                            [
                                Pruning,for children={visible on=<<3->>}
                                    [
                                        Gaussian Covisibility,key
                                    ]
                            ]
                    ]
            ]
        ]
    \end{forest}
}
\resizebox{0.08\textwidth}{!}{
    \begin{tikzpicture}[visible on=<<3->>]
        \node [my node for tree, draw=YellowGreen] (trick node) {trick};
        \node [my node for tree, draw=OrangeRed, above of = trick node] {key method};
        \node [my node for tree, draw=Cyan, below of = trick node] (convention) {convention};
    \end{tikzpicture}
}
    ]], {})
    ),
}
