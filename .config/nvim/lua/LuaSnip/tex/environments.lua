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
    });
end

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
\begin{itemize}<>
    \item <>
\end{itemize}
    ]],
            { c(1, { t("\\setlength{\\itemsep}{1.5ex}"), t("") }), i(2, "some content"), }
        )
    ),
    s({ trig = "enu" },
        fmta(
            [[
\begin{enumerate}<>
    \item <>
\end{enumerate}
    ]],
            { c(1, { t("\\setlength{\\itemsep}{1.5ex}"), t("") }), i(2, "some content"), }
        )
    ),
    s({ trig = "figure" },
        fmta(
            [[
\begin{figure}[<>]
    \centering
    \includegraphics[width=0.<>\linewidth]{<>}
    \smallskip
    \caption{<>}
    % \label{fig:<>}
\end{figure}
    ]],
            { i(1, "htbp"), i(2, "7"), i(3, "example-image"), i(4), rep(4) }
        )
    ),
    s({ trig = "minipage" },
        fmta(
            [[
    \begin{minipage}[<>]{<>\linewidth}
        <>
    \end{minipage}
    ]],
            { c(1, { t("c"), t("t"), t("b") }), i(2, ".4"), i(3, "\\includegraphics[width=0.5\\linewidth]{example-image}") }

        )
    ),
    s({ trig = "minipage-two" },
        fmta(
            [[
\begin{figure}[htbp]
    \begin{minipage}[c]{0.45\linewidth}
       \centering
       \includegraphics[width=.5\linewidth]{<>}
    \end{minipage}
    \hspace{\fill}
    \begin{minipage}[c]{0.45\linewidth}
       \centering
       \includegraphics[width=.5\linewidth]{<>}
    \end{minipage}
    \smallskip
    \caption{Caption}
\end{figure}
    ]],
            { i(1, "example-image"), i(2, "example-image") }
        )
    ),
    s({ trig = "table" },
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
