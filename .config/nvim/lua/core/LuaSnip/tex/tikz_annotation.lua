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
    -- TODO: make it context-aware
    s(
        { trig = "preamble-equation-annotation", dscr = "ref: https://github.com/synercys/annotated_latex_equations" },
        fmta([[
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%% equation annotation by TikZ %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % \usepackage{tikz}
        % \usepackage[dvipsnames]{xcolor}
        % \usetikzlibrary{calc,tikzmark}
        % \usepackage{tcolorbox}

        \usepackage{makecell}
        \usepackage{xstring}

        % Usage:
        % \annotatedEquation{1: color/colorseries}{2: node name}{3: node direction}{4: x shift}{5: y shift}{6: anchor direction}{7: color/colorseries name}{8: annotation}{9: baseline direction}
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

        \definecolorseries{marknode-color-series}{hsb}{last}[hsb]{0.0,0.15,0.95}[hsb]{0.99,0.15,0.95}
        \definecolorseries{annotate-color-series}{hsb}{last}[hsb]{0.0,0.8,0.65}[hsb]{0.99,0.8,0.65}
        \resetcolorseries[12]{marknode-color-series}
        \resetcolorseries[12]{annotate-color-series}
    ]]
        , {})
    ),
    s({ trig = "env-equation-annotation" },
        fmta(
            [[
        \begin{tikzpicture}[overlay,remember picture,>>=stealth,nodes={align=left,inner ysep=1pt},<<-]
            <>
        \end{tikzpicture}
    ]],
            { i(1, "Use \\annotatedEquation here.") }
        )
    ),
    s({ trig = "tikzmarknode" },
        fmta(
            [[
        \tikzmarknode{<>}{\colorbox{<>}{\(<>\)}}
    ]],
            { i(2, "marknode name"), i(3, "color name"), d(1, get_visual) }
        )
    ),
    s({ trig = "equation-annotation" },
        fmta(
            [[
			\annotatedEquation{<>}{<>}{<>}{<>}{<>}{<>}{<>}{<>}{<>}
    ]],
            { c(1, { t("colorseries"), t("color") }), i(2, "tikzmarknode name"), c(3, { t("south"), t("north") }), i(4,
                "x shift"), i(5,
                "y shift"), c(6, { t("north east"), t("north west"), t("south east"), t("south west") }), i(7,
                "color/colorseires name"), i(8, "annotation"), c(9, { t("west"), t("east") }) }
        )
    ),
    s({ trig = "preamble-figure-annotation" },
        fmta([[
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%% figure annotation by TikZ  %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Usage:
        %     \annotatedFigureBoxCustom{1: bottom-left}{2: top-right}{3: label}{4: label-position}{5: box-color}{6: label-color}{7: border-color}{8: text-color}
        \newcommand*\annotatedFigureBoxCustom[8]{
            \draw[#5,ultra thick] (#1) rectangle (#2); \node at (#4) [fill=#6,thick,shape=rectangle,draw=#7,inner sep=2.5pt,font=\small\sffamily,text=#8] { #3 };
        }
        % Usage:
        %     \annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
        \newcommand*\annotatedFigureBox[4]{
            \annotatedFigureBoxCustom{#1}{#2}{#3}{#4}{color-progressbar}{color-progressbar}{color-progressbar}{black!2}
        }
        \newcommand*\annotatedFigureText[4]{\node[draw=none, anchor=south west, text=#2, inner sep=0, text width=#3\linewidth,font=\sffamily] at (#1){#4};}
        \newenvironment{annotatedFigure}[1]{
            \centering
            \begin{tikzpicture}
                \node[anchor=south west,inner sep=0] (image) at (0,0) { #1 };
            \begin{scope}[x={(image.south east)},y={(image.north west)}]
        }
        {
            \end{scope}
            \end{tikzpicture}
        }
        % Usage:
        %     \figureBox{bottom-left}{top-right}{color}{thickness}
        \newcommand*\figureBox[4]{\draw[#3,#4,rounded corners] (#1) rectangle (#2);}
    ]], {})
    ),
    s({ trig = "env-figure-annotation" },
        fmta([[
        \begin{annotatedFigure}
            {\includegraphics[width=0.5\linewidth]{<>}}
        \end{annotatedFigure}
    ]], { i(1, "example-image") })
    ),
    s({ trig = "figure-annotation" },
        fmta([[
            \annotatedFigureBox{<>}{<>}{<>}{<>}
    ]], { i(1, "bottom-left, e.g. 0,0"), i(2, "top-right, e.g. 1,1"), i(3, "annotation"), rep(1) })
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- timeline -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "timeline-example" },
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
    --------------------------- mindmap concept example ----------------------------
    --------------------------------------------------------------------------------
    s({ trig = "mindmap-concept-example" },
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
    s({ trig = "mindmap-taxonomy-example" },
        fmta([[
        	\usetikzlibrary{shadows}
            \tikzset{
                my node for tree/.style={
                        text=black,
                        draw=lightgray!50,
                        inner color=lightgray!5,
                        outer color=lightgray!20,
                        thick,
                        minimum width=12mm,
                        minimum height=6mm,
                        rounded corners=3,
                        text height=1.5ex,
                        text depth=0ex,
                        font=\sffamily\bf,
                        drop shadow,
                    }
            }
            \forestset{
                my tree/.style={
                        my node for tree,
                        s sep+=4pt,
                        l sep+=15pt,
                        grow'=east,
                        edge={lightgray, thin},
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
            \colorlet{easy-for-slam}{ForestGreen}
            \colorlet{not-so-easy-for-slam}{MidnightBlue}
            \colorlet{hard-for-slam}{Maroon}
            \resizebox{!}{0.65\textheight}{
                \begin{forest}
                    for tree={
                    my tree
                    },
                    [
                            \textcolor{color-frametitle}{\bf Semantic 3DGS} [
                                \textbf{Accuracy} [
                                    \textcolor{not-so-easy-for-slam}{DINO}\,\textcolor{blue!70}{\SnowflakeChevron}
                                ][
                                    \textcolor{not-so-easy-for-slam}{SAM Feature-based Distillation}\,\textcolor{blue!70}{\SnowflakeChevron}
                                ][
                                    \textcolor{easy-for-slam}{SAM Response-based Distillation}\,\textcolor{blue!70}{\SnowflakeChevron}
                                ][
                                    \textcolor{easy-for-slam}{3D Prior Regularization}
                                ][
                                    \textcolor{not-so-easy-for-slam}{Spatial Feature Fusion}
                                ][
                                    \textcolor{not-so-easy-for-slam}{3D Segmentation}
                                ]
                            ][
                                \textbf{Efficiency} [
                                    \textcolor{easy-for-slam}{Dimensionality Alignment}
                                ][
                                    \textcolor{easy-for-slam}{Index/Grid Map}
                                ][
                                    \textcolor{hard-for-slam}{Self-supervised Embedding Compression}
                                ]
                            ][
                                \textbf{Consistency} [
                                    \textcolor{easy-for-slam}{Zero-shot Video Tracker}\,\textcolor{blue!70}{\SnowflakeChevron}
                                ][
                                    \textcolor{easy-for-slam}{Multi-View Association}
                                ][
                                    \textcolor{hard-for-slam}{Multi-View Contrastive Learning}
                                ]
                            ]
                        ]
                \end{forest}
            }
    ]], {})
    ),
}
