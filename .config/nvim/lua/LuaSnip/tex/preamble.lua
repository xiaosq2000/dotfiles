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
    s({ trig = "beamer-preamble-all-in-one" },
        fmta(
            [[
\documentclass[10pt,aspectratio=1610]{beamer}
\usetheme[subsectionpage=progressbar,progressbar=frametitle,block=fill]{moloch}
\mode<<presentation>>

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% color %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{xcolor} % pre-loaded by beamer
\definecolor{kongquelan}{RGB}{14,176,201}
\definecolor{koushaolv}{RGB}{93,190,138}
\definecolor{yingwulv}{RGB}{91,174,35}
\definecolor{shenhuilan}{RGB}{19,44,51}
\definecolor{jianniaolan}{RGB}{20,145,168}
\definecolor{jiguanghong}{RGB}{243,59,31}
\definecolor{xiangyehong}{RGB}{240,124,130}
%
\definecolor{red}{HTML}{E9002D}
\definecolor{amber}{HTML}{FFAA00}
\definecolor{green}{HTML}{00B000}
%
\definecolor{um-blue}{HTML}{002855}
\definecolor{um-gold}{HTML}{84754E}
\definecolor{um-red}{HTML}{Ef3340}
\definecolor{um-yellow}{HTML}{84754E}
%
% \colorlet{blue}{um-blue}
% \colorlet{gold}{um-gold}
% \colorlet{red}{um-red}
% \colorlet{yellow}{um-yellow}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% personal modification of the beamer theme %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\useinnertheme{rectangles}

% color
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% figure annotation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{tikz} % pre-loaded by beamer

%\annotatedFigureBoxCustom{1: bottom-left}{2: top-right}{3: label}{4: label-position}{5: box-color}{6: label-color}{7: border-color}{8: text-color}
\newcommand*\annotatedFigureBoxCustom[8]{
    \draw[#5,ultra thick] (#1) rectangle (#2);
    \node at (#4) [fill=#6,thick,shape=rectangle,draw=#7,inner sep=2.5pt,font=\small\sffamily,text=#8] { #3 };
}
%\annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
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
%\figureBox{bottom-left}{top-right}{color}{thickness}
\newcommand*\figureBox[4]{\draw[#3,#4,rounded corners] (#1) rectangle (#2);}

\usetikzlibrary{calc,tikzmark}
% \usepackage{tcolorbox} % pre-loaded by beamer
\usepackage{makecell}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%% pdf, svg, animation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{pdfpages}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% others %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{lipsum}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% reference %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage[natbib=true, backend=biber, style=authoryear-icomp, useprefix=true, style=ieee]{biblatex}
% \addbibresource{../references/reference.bib}
\AtBeginBibliography{\scriptsize}

\usepackage{hyperref}
\hypersetup{
    colorlinks=true,
    linkcolor=.,
    anchorcolor=.,
    filecolor=.,
    menucolor=.,
    runcolor=.,
    urlcolor=cyan,
    citecolor=.,
}

\title{Beamer Slides}
\subtitle{Using moloch theme}
\author{Author}

\begin{document}
\begin{frame}
    \frametitle
\end{frame}
\begin{frame}{Outline}
	\tableofcontents
\end{frame}
% \appendix
% \section{\appendixname}
% \subsection{References}
% \begin{frame}[allowframebreaks]
% 	\frametitle{References}
% 	\nocite{*}
% 	\printbibliography[heading=none]
% \end{frame}
\end{document}
    ]], {}
        )
    ),
    s({ trig = "figure-annotation-preamble" },
        fmta(
            [[
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% figure annotation %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{tikz} % pre-loaded by beamer

% Usage: \annotatedFigureBoxCustom{1: bottom-left}{2: top-right}{3: label}{4: label-position}{5: box-color}{6: label-color}{7: border-color}{8: text-color}
\newcommand*\annotatedFigureBoxCustom[8]{
    \draw[#5,ultra thick] (#1) rectangle (#2);
    \node at (#4) [fill=#6,thick,shape=rectangle,draw=#7,inner sep=2.5pt,font=\small\sffamily,text=#8] { #3 };
}
% \annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
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
% Usage: \figureBox{bottom-left}{top-right}{color}{thickness}
\newcommand*\figureBox[4]{\draw[#3,#4,rounded corners] (#1) rectangle (#2);}

\usepackage{makecell}
\usetikzlibrary{calc,tikzmark}
\usepackage{tcolorbox} % pre-loaded by beamer
\colorlet{1_marknode_color}{cyan!20}
\colorlet{1_annotate_color}{cyan!60}
\colorlet{2_marknode_color}{green!20}
\colorlet{2_annotate_color}{green!60}
\colorlet{3_marknode_color}{um-red!15}
\colorlet{3_annotate_color}{um-red!55}
    ]], {}
        )
    ),
    s({ trig = "hyperref", dscr = "" },
        fmta([[
            \usepackage{hyperref}
            \hypersetup{
                colorlinks=true,
                linkcolor=.,
                anchorcolor=.,
                filecolor=.,
                menucolor=.,
                runcolor=.,
                urlcolor=.,
                citecolor=.,
            }
        ]]
        , {})
    ),
}
