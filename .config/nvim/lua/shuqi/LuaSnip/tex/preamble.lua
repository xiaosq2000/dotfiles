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
    s({ trig = "beamer-preamble", dscr = "based on metropolis theme, all in one" }, fmta([[
\documentclass[utf-8, 10pt, aspectratio=1610]{beamer}
\mode<<presentation>>
\usetheme[
background=light,
titleformat=regular,
% subsectionpage=progressbar,
subsectionpage=none,
block=fill,
]{metropolis}
\usepackage{appendixnumberbeamer}
\usepackage{fontawesome5}
% fontspec is preloaded
    % \setsansfont[BoldFont={Fira Sans SemiBold}]{Fira Sans Book}
    \setmainfont{Source Serif 4}

\usepackage{xcolor}
    % ref: http://zhongguose.com
    \definecolor{kongquelan}{RGB}{14,176,201}
    \definecolor{shenhuilan}{RGB}{19,44,51}
    \definecolor{jianniaolan}{RGB}{20,145,168}
    \definecolor{koushaolv}{RGB}{93,190,138}
    \definecolor{yingwulv}{RGB}{91,174,35}
    \definecolor{jiguanghong}{RGB}{243,59,31}
    \definecolor{xiangyehong}{RGB}{240,124,130}
    \definecolor{xinghuang}{RGB}{250,142,22}
    \definecolor{lusuihui}{RGB}{189,174,173}
\usepackage{tikz}
\usetikzlibrary{calc,tikzmark}
\usepackage{tcolorbox}
\colorlet{red_marknode}{xiangyehong!50}
\colorlet{red_annotate}{xiangyehong}
\colorlet{blue_marknode}{jianniaolan!50}
\colorlet{blue_annotate}{jianniaolan}
\colorlet{green_marknode}{yingwulv!50}
\colorlet{green_annotate}{yingwulv}
\colorlet{gray_marknode}{lusuihui!50}
\colorlet{gray_annotate}{lusuihui}
\usepackage{booktabs}
\usepackage{caption}
\usepackage{graphicx}

\usepackage[backend=biber,natbib=true,style=ext-numeric-comp,sorting=none,backref=true]{biblatex}
\addbibresource{references.bib}
\renewcommand*{\bibfont}{\normalfont\small}
\DeclareOuterCiteDelims{cite}{\textcolor{yingwulv}{\bibopenbracket}}{\textcolor{yingwulv}{\bibclosebracket}}

\usepackage{amsmath}
\usepackage{amsfonts}
\usepackage{amsthm}
\usepackage{mathtools}
\usepackage{cases} % numcases
% ref: https://tex.stackexchange.com/a/602213/240783
\usepackage{empheq}
\usepackage{eqparbox}
\newcommand{\eqmath}[3][c]{%
  % #1 = alignment, default c, #2 = label, #2 = math material
  \eqmakebox[#2][#1]{$\displaystyle#3$}%
}
\newcommand{\eqtext}[3][c]{%
  % #1 = alignment, default c, #2 = label, #2 = text material
  \eqmakebox[#2][#1]{#3}%
}
\hypersetup{
    colorlinks=true,
    linkcolor=xinghuang!80,
    anchorcolor=.,
    filecolor=.,
    menucolor=.,
    runcolor=.,
    urlcolor=jianniaolan,
    citecolor=yingwulv,
}

\title{<>}
\subtitle{<>}
\author{shuqi}
\date{\today}
\institute{
    \faGithub\;
    \href{https://github.com/xiaosq2000}{xiaosq2000}
    \quad
    \faEnvelope\;
    \href{xiaosq2000@gmail.com}{xiaosq2000@gmail.com}
}
\begin{document}
    \maketitle
    \begin{frame}{Hello}
    \end{frame}
\end{document}
    ]], { i(1, "title"), i(2, "subtitle")})),
}
