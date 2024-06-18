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
    s({ trig = "beamer-example" },
        fmta(
            [[
\documentclass[
    10pt,
    aspectratio=1610,
    % handout
]{beamer}
\usetheme[
    subsectionpage=progressbar,
    progressbar=frametitle,
    block=transparent
]{moloch}
\mode<<presentation>>

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% personal modification of the beamer theme %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% inner theme
\useinnertheme{rectangles}

% color
% \usepackage{xcolor} % pre-loaded by beamer
\definecolor{um-blue}{HTML}{002855}
\definecolor{um-gold}{HTML}{84754E}
\definecolor{um-red}{HTML}{Ef3340}
\definecolor{um-yellow}{HTML}{84754E}

\setbeamercolor{frametitle}{fg=black!2, bg=um-blue}
\setbeamercolor{progress bar}{fg=um-gold, bg=um-gold!20}
\setbeamercolor{item projected}{fg=black!2, bg=um-gold}
\setbeamercolor{itemize item}{fg=um-gold}

% progress width
\makeatletter
\setlength{\moloch@titleseparator@linewidth}{2.5pt}
\setlength{\moloch@progressonsectionpage@linewidth}{2.5pt}
\setlength{\moloch@progressinheadfoot@linewidth}{2.5pt}
\makeatother

% make footnotesize smaller
\let\oldfootnotesize\footnotesize
\renewcommand*{\footnotesize}{\oldfootnotesize\tiny}

% footnote without counter
\newcommand\blfootnote[1]{%
  \begingroup
  \renewcommand\thefootnote{}\footnote{#1}%
  \addtocounter{footnote}{-1}%
  \endgroup
}

% footnotetext without counter
\newcommand\blfootnotetext[1]{%
  \begingroup
  \renewcommand\thefootnotetext{}\footnotetext{#1}%
  \addtocounter{footnotetext}{-1}%
  \endgroup
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% table %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{booktabs}

% ref: https://tex.stackexchange.com/a/614273/240783
\usepackage{tabularray}
\UseTblrLibrary{booktabs}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% caption %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{caption}
\captionsetup{font={scriptsize},
              labelfont={scriptsize},
              textfont={scriptsize},
              % hypcap=false,
              % format=hang,
              % margin=1cm
             }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% glyph %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{fontawesome5}
\usepackage{pifont}
\newcommand{\cmark}{\ding{51}}
\newcommand{\xmark}{\ding{55}}
\usepackage{romannum}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% graphics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{graphicx} % pre-loaded by beamer
    \graphicspath{{../images}}

% \usepackage{tikz} % pre-loaded by beamer

% \usepackage{tcolorbox} % pre-loaded by beamer

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%% tikz figure annotation %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Usage:
%     \annotatedFigureBoxCustom{1: bottom-left}{2: top-right}{3: label}{4: label-position}{5: box-color}{6: label-color}{7: border-color}{8: text-color}
\newcommand*\annotatedFigureBoxCustom[8]{
    \draw[#5,ultra thick] (#1) rectangle (#2); \node at (#4) [fill=#6,thick,shape=rectangle,draw=#7,inner sep=2.5pt,font=\small\sffamily,text=#8] { #3 };
}
% Usage:
%     \annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
\newcommand*\annotatedFigureBox[4]{
    \annotatedFigureBoxCustom{#1}{#2}{#3}{#4}{um-gold}{um-gold}{um-gold}{black!2}
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

\usetikzlibrary{calc,tikzmark,arrows.meta,fit,positioning,decorations.markings}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% tikz helpful grid %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Reference: https://tex.stackexchange.com/a/39698/240783
% Usage:
%     \draw (-2,-2) to[grid with coordinates] (7,4);
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

\usepackage{makecell}
\usepackage{forest}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% pdf, svg, animation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{pdfpages}
\usepackage{svg}
\usepackage{animate}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% others %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{lipsum}
\usepackage{adjustbox}
\usepackage{stmaryrd} % \mapsfrom

% Usage: Map numbers to alphabets
% Example: \Letter{1} prints A, \Letter{2} prints B
\makeatletter
\newcommand{\Letter}[1]{\@Alph{#1}}
\makeatother

\usepackage{bbding}
\usepackage[weather]{ifsym}
% \usetikzlibrary{shapes.geometric,positioning}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% reference %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage[backref=true, natbib=true, backend=biber, style=authoryear-icomp, useprefix=true, style=ieee]{biblatex}
\AtBeginBibliography{\scriptsize}
\addbibresource{sample.bib}

\usepackage{hyperref}
\hypersetup{
    colorlinks=true,
    linkcolor=.,
    anchorcolor=.,
    filecolor=.,
    menucolor=.,
    runcolor=.,
    urlcolor=cyan,
    citecolor=cyan,
}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% meta info %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\title{A template for slides}
\subtitle{Beamer, TikZ, ...}
\author{Shuqi XIAO}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% document %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\begin{document}

\begin{frame}{Outline}
	\tableofcontents
\end{frame}

\appendix
\section{\appendixname}
\subsection{References}
\begin{frame}[allowframebreaks]
	\frametitle{References}
	\nocite{*}
	\printbibliography[heading=none]
\end{frame}

\end{document}
]], {}
        )
    ),
}
