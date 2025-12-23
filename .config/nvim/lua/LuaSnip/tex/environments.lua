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
local rec_ls
rec_ls = function()
	return sn(nil, {
		c(1, {
			-- important!! Having the sn(...) as the first choice will cause infinite recursion.
			t({ "" }),
			-- The same dynamicNode as in the snippet (also note: self reference).
			sn(nil, { t({ "", "\t\\item " }), i(1), d(2, rec_ls, {}) }),
		}),
	})
end

return {
	s(
		{ trig = "e", dscr = "environment" },
		fmta(
			[[
\begin{<>}
    <>
\end{<>}
    ]],
			{
				i(1),
				i(2),
				rep(1),
			}
		)
	),
	s(
		{ trig = "eq", dscr = "equation" },
		fmta(
			[[
\begin{equation}
    <>
\end{equation}
    ]],
			{ i(1) }
		)
	),
	s(
		{ trig = "eqn", dscr = "equation" },
		fmta(
			[[
\begin{eqnarray}
    <>
\end{eqnarray}
    ]],
			{ i(1) }
		)
	),
	s(
		{ trig = "al", dscr = "align" },
		fmta(
			[[
\begin{align}
    <>
\end{align}
    ]],
			{ i(1) }
		)
	),
	s(
		{ trig = "ald", dscr = "aligned" },
		fmta(
			[[
\begin{aligned}
    <>
\end{aligned}
    ]],
			{ i(1) }
		)
	),
	s(
		{ trig = "itm", dscr = "itemize" },
		fmta(
			[[
\begin{itemize}<>
    \item <>
\end{itemize}
    ]],
			{ c(1, { t(""), t("\\setlength{\\itemsep}{1.5ex}") }), i(2, "some content") }
		)
	),
	s(
		{ trig = "enu", dscr = "enumerate" },
		fmta(
			[[
\begin{enumerate}<>
    \item <>
\end{enumerate}
    ]],
			{ c(1, { t(""), t("\\setlength{\\itemsep}{1.5ex}") }), i(2, "some content") }
		)
	),
	s(
		{ trig = "fig", dscr = "figure" },
		fmta(
			[[
\begin{figure}[<>]
    \centering
    \includegraphics[width=0.<>\linewidth]{<>}
    % \caption{<>}
    % \label{fig:<>}
\end{figure}
    ]],
			{ i(1, "htbp"), i(2, "7"), i(3, "example-image"), i(4), rep(4) }
		)
	),
	s(
		{ trig = "video", dscr = "video" },
		fmta(
			[[
\begin{video}[<>]
    \centering
    \movie[<><><>]{\includegraphics[<>]{<>}}{<>}
    % \caption{<>}
    % \label{fig:<>}
\end{video}
    ]],
			{
				i(1, "htbp"),
				c(2, { t(""), t("showcontrols,") }),
				c(3, { t(""), t("autostart,") }),
				c(4, { t(""), t("loop") }),
				i(5, "width=.75\\linewidth"),
				i(6, "example-image"),
				i(7, "video-filepath"),
				i(8, ""),
				rep(8),
			}
		)
	),
	s(
		{ trig = "mp", dscr = "minipage" },
		fmta(
			[[
    \begin{minipage}[<>]{<>\linewidth}
        \centering
        <>
    \end{minipage}
    ]],
			{
				c(1, { t("t"), t("c"), t("b") }),
				i(2, ".4"),
				i(3, "\\includegraphics[width=0.5\\linewidth]{example-image}"),
			}
		)
	),
	s(
		{ trig = "tab", dscr = "table" },
		fmta(
			[[
\begin{table}[<>]
    \centering
    \begin{tblr}{<>}
        \toprule
        Column 1 & Column 2 \\
        \midrule
        Hello & World \\
        \midrule[dashed]
        Hello & World \\
        \bottomrule
    \end{tblr}
    % \smallskip
    % \caption{<>}
    % \label{table:<>}
\end{table}
    ]],
			{ i(1, "htbp"), i(2, "XX"), i(3, ""), rep(3) }
		)
	),
	s(
		{ trig = "quote", dscr = "quote" },
		fmta(
			[[
\begin{quote}
    <>
    \flushright ---\;\textrm{<>}
\end{quote}
    ]],
			{ i(1, "put the quote here"), i(2, "put the person here") }
		)
	),
	s(
		{ trig = "blk", dscr = "block" },
		fmta(
			[[
\begin{block}{<>}
    <>
\end{block}
    ]],
			{ i(1, "put the title here"), i(2, "put the contents here") }
		)
	),
	s(
		{ trig = "def", dscr = "definition" },
		fmta(
			[[
\begin{definition}[<>]
    <>
\end{definition}
    ]],
			{ i(1), i(2) }
		)
	),
	s(
		{ trig = "theo", dscr = "theorem" },
		fmta(
			[[
\begin{theorem}[<>]
    <>
\end{theorem}
    ]],
			{ i(1), i(2) }
		)
	),
	s(
		{ trig = "corollary", dscr = "crly" },
		fmta(
			[[
\begin{corollary}[<>]
    <>
\end{corollary}
    ]],
			{ i(1), i(2) }
		)
	),
	s(
		{ trig = "lem", dscr = "lemma" },
		fmta(
			[[
\begin{lemma}[<>]
    <>
\end{lemma}
    ]],
			{ i(1), i(2) }
		)
	),
	s(
		{ trig = "rmk", dscr = "remark" },
		fmta(
			[[
\begin{block}{Remark\ (<>)}
    <>
\end{block}
    ]],
			{ i(1), i(2) }
		)
	),
}
