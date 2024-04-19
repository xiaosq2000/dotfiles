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
    s({ trig = "e" },
        fmta(
            [[
\begin{<>}
    <>
\end{<>}
    ]],
            {
                i(1), i(2), rep(1)
            }
        )
    ),
    s({ trig = "eq" },
        fmta(
            [[
\begin{equation}
    <>
\end{equation}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "eqn" },
        fmta(
            [[
\begin{eqnarray}
    <>
\end{eqnarray}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "al" },
        fmta(
            [[
\begin{align}
    <>
\end{align}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "ald" },
        fmta(
            [[
\begin{aligned}
    <>
\end{aligned}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "itm" },
        fmta(
            [[
\begin{itemize}
    \setlength{\itemsep}{1.5ex}
    \item <>
\end{itemize}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "enu" },
        fmta(
            [[
\begin{enumerate}
    \setlength{\itemsep}{1.5ex}
    \item <>
\end{enumerate}
    ]],
            { i(1) }
        )
    ),
    s({ trig = "frame" },
        fmta(
            [[
\begin{frame}{<>}
    \vspace*{\fill}
    <>
    \vspace*{\fill}
\end{frame}
    ]],
            { i(1, "Title"), i(2, "Hello") }
        )
    ),
    s({ trig = "figure" },
        fmta(
            [[
\begin{figure}[<>]
    \centering
    \includegraphics[width=0.<>\linewidth]{<>}
    \vspace*{0.5ex}
    \caption{<>}
    \label{fig:<>}
\end{figure}
    ]],
            { i(1, "htbp"), i(2, "7"), i(3, "path"), i(4), rep(4) }
        )
    ),
    s({ trig = "minipage" },
        fmta(
            [[
\begin{figure}[htbp]
    \begin{minipage}[c]{0.45\linewidth}
       \centering
       \includegraphics[width=\linewidth]{<>}
    \end{minipage}
    \hspace{\fill}
    \begin{minipage}[c]{0.45\linewidth}
       \centering
       \includegraphics[width=\linewidth]{<>}
    \end{minipage}
    \caption{Caption}
\end{figure}
    ]],
            { i(1, "path"), i(2, "path") }
        )
    ),
    s({ trig = "table" },
        fmta(
            [[
\begin{table}[<>]
    \centering
    \begin{tabular}{<>}
        \toprule
        \midrule
        \bottomrule
    \end{tabular}
    \caption{<>}
    \label{table:<>}
\end{table}
    ]],
            { i(1, "htbp"), i(2, "cc"), i(3, ""), rep(3) }
        )
    ),
    s({ trig = "quote" },
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
    s({ trig = "block" },
        fmta(
            [[
\begin{block}{<>}
    <>
\end{block}
    ]],
            { i(1, "put the title here"), i(2, "put the contents here") }
        )
    ),
    s({ trig = "definition" },
        fmta(
            [[
\begin{definition}[<>]
    <>
\end{definition}
    ]],
            { i(1), i(2) }
        )
    ),
    s({ trig = "theorem" },
        fmta(
            [[
\begin{theorem}[<>]
    <>
\end{theorem}
    ]],
            { i(1), i(2) }
        )
    ),
    s({ trig = "corollary" },
        fmta(
            [[
\begin{corollary}[<>]
    <>
\end{corollary}
    ]],
            { i(1), i(2) }
        )
    ),
    s({ trig = "lemma" },
        fmta(
            [[
\begin{lemma}[<>]
    <>
\end{lemma}
    ]],
            { i(1), i(2) }
        )
    ),
    s({ trig = "remark" },
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
