local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local c = ls.choice_node
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
    s({ trig = "at" },
        fmta("\\alert<<<>>>{<>}", { i(1, ""), d(2, get_visual) })
    ),
    s({ trig = "uc" },
        fmta("\\uncover<<<>>>{<>}", { i(1, "+(1)-"), d(2, get_visual) })
    ),
    s({ trig = "md" },
        fmta("\\mode<<<>>>{<>}", { c(1, { t({ 'presentation' }), t({ 'article' }) }), d(2, get_visual) })
    ),
    s({ trig = "beamer-example" },
        fmta(
            [[
\documentclass[
    10pt,
    aspectratio=1610,
    xcolor={dvipsnames,pst},
    % handout
]{beamer}
\usetheme[
    subsectionpage=progressbar,
    progressbar=frametitle,
    block=transparent
]{moloch}
\mode<<presentation>>
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%% personal modification of the moloch/metropolis theme %%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% frametitle with right-aligned "section, subsection"
\newenvironment{Frame}[1]{
    \begin{frame}{#1 \hspace{0pt plus 1filll} \scriptsize \(\triangleleft\)\;\subsecname\;\(\triangleleft\)\;\secname}\vspace*{\fill}
}{\vspace*{\fill}\end{frame}}

% inner theme
\useinnertheme{rectangles}

% color palette
\definecolor{um-blue}{HTML}{002855}
\definecolor{um-gold}{HTML}{84754E}
\definecolor{um-red}{HTML}{Ef3340}
\definecolor{um-yellow}{HTML}{84754E}
% color theme
\colorlet{color-frametitle}{um-blue}
\colorlet{color-progressbar}{um-gold}

\setbeamercolor{frametitle}{fg=black!2, bg=color-frametitle}
\setbeamercolor{progress bar}{fg=color-progressbar, bg=color-progressbar!20}
\setbeamercolor{item projected}{fg=black!2, bg=color-progressbar}
\setbeamercolor{itemize item}{fg=color-progressbar}

% make progress bar's width larger
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% fonts %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{xeCJK}
\setCJKmainfont{思源宋体}
\setCJKsansfont{思源黑体}
\setCJKmonofont{思源等宽}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% color %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\definecolorseries{marknode-color-series}{hsb}{last}[hsb]{0.0,0.12,0.95}[hsb]{0.95,0.12,0.95}
\definecolorseries{annotation-color-series}{hsb}{last}[hsb]{0.0,0.8,0.65}[hsb]{0.95,0.8,0.65}
\resetcolorseries[8]{marknode-color-series}
\resetcolorseries[8]{annotation-color-series}

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% glyph %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\usepackage{fontawesome5}
\usepackage{bbding}
\usepackage{pifont}
\newcommand{\cmark}{\ding{51}}
\newcommand{\xmark}{\ding{55}}
\usepackage{romannum}
\usepackage{stmaryrd} % for \mapsfrom (inverse of \mapsto)

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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% graphics %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% \usepackage{graphicx} % pre-loaded by beamer
\graphicspath{{./images}}

\usepackage{forest} % mindmap

% \usetikzlibrary{calc,tikzmark,arrows.meta,fit,positioning,decorations.markings}

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

% Usage: Map numbers to alphabets
% Example: \Letter{1} prints A, \Letter{2} prints B
\makeatletter
\newcommand{\Letter}[1]{\@Alph{#1}}
\makeatother

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
\title{Academic Slides}
\subtitle{a template based on Beamer, TikZ, ...}
\author{Shuqi XIAO}
% \logo{
%     \includegraphics[width=1.5cm]{example-image}
% }
% \titlegraphic{
%     \begin{tikzpicture}[remember picture, overlay]
%         \usetikzlibrary{calc}
%         \node [anchor=north east] at ($(current page.north east)+(-2.5em,-2.5em)$) {
%             \includegraphics[width=3cm]{example-image}
%         };
%     \end{tikzpicture}
% }

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% document %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\begin{document}

\maketitle

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
