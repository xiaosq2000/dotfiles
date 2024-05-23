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
    s({ trig = "beamer-template" },
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%% personal modification of the beamer theme %%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% color
\setbeamercolor{frametitle}{fg=black!2, bg=um-blue}
\setbeamercolor{progress bar}{fg=um-gold, bg=um-gold!30}

% progress width 
\makeatletter
\setlength{\moloch@titleseparator@linewidth}{1.5pt}
\setlength{\moloch@progressonsectionpage@linewidth}{1.5pt}
\setlength{\moloch@progressinheadfoot@linewidth}{1.5pt}
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

%\annotatedFigureBoxCustom{bottom-left}{top-right}{label}{label-position}{box-color}{label-color}{border-color}{text-color}
\newcommand*\annotatedFigureBoxCustom[8]{
    \draw[#5,thick,rounded corners] (#1) rectangle (#2); 
    \node at (#4) [fill=#6,thick,shape=circle,draw=#7,inner sep=2pt,font=\sffamily,text=#8] { \textbf{#3} };
}
%\annotatedFigureBox{bottom-left}{top-right}{label}{label-position}
\newcommand*\annotatedFigureBox[4]{
    \annotatedFigureBoxCustom{#1}{#2}{#3}{#4}{red!40}{red!20}{red!20}{black}
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
\usepackage{tcolorbox}
\colorlet{marknode_color}{cyan!30}
\colorlet{annotate_color}{cyan!60}

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
\maketitle
\begin{frame}{Outline}
	\tableofcontents
\end{frame}
\section{Introduction}
\begin{frame}{Introduction}
	\lipsum[1]
	\blfootnote{Hi, there.}
\end{frame}
\begin{frame}{Title}
	\vspace*{\fill}
	\begin{theorem}[Fourier Transform]
		\begin{equation}
			\mathcal{F}\left(f\,(t)\right) = \tikzmarknode{integration}{\colorbox{marknode_color}{\(\displaystyle \int_{-\infty}^{+\infty}\)}} f\,(t) \mathrm{e}^{-\omega t} \operatorname{d}\! t
		\end{equation}
		{
		\begin{tikzpicture}[overlay,remember picture,>>=stealth,nodes={align=left,inner ysep=1pt},<<-]
			\path (integration.south) ++ (0em,-0.5em) node[anchor=north east,color=annotate_color] (integration_annotate) {\scriptsize{integration}};
			\draw [color=annotate_color] (integration.south) |- (integration_annotate.south west);
			\annotatedFigureBox{0,0}{0.5,0.5}{1}{0,0}
		\end{tikzpicture}
		}
	\end{theorem}
	\vspace*{\fill}
\end{frame}
\appendix
\section{\appendixname}
\subsection{References}
% \begin{frame}[allowframebreaks]
% 	\frametitle{References}
% 	\nocite{*}
% 	\printbibliography[heading=none]
% \end{frame}
\end{document}
    ]], {}
        )
    )
}
