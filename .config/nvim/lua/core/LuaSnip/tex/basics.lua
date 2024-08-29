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
local tex = {}
tex.in_mathzone = function()
    return vim.fn['vimtex#syntax#in_mathzone']() == 1
end
tex.in_text = function()
    return not tex.in_mathzone()
end

return {
    --------------------------------------------------------------------------------
    ------------------------------------ fonts -------------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "trm" },
        fmta("\\textrm{<>}", { d(1, get_visual) })
    ),
    s({ trig = "tit" },
        fmta("\\textit{<>}", { d(1, get_visual) })
    ),
    s({ trig = "tbf" },
        fmta("\\textbf{<>}", { d(1, get_visual) })
    ),
    s({ trig = "ttt" },
        fmta("\\texttt{<>}", { d(1, get_visual) })
    ),
    s({ trig = "tsf" },
        fmta("\\textsf{<>}", { d(1, get_visual) })
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- spacing ------------------------------------
    --------------------------------------------------------------------------------
    s({ trig = ";h", snippetType = "autosnippet" },
        fmta([[\hspace*{<>}]], { i(1, "\\fill") })
    ),
    s({ trig = ";v", snippetType = "autosnippet" },
        fmta([[\vspace*{<>}]], { i(1, "1.5ex") })
    ),
    --------------------------------------------------------------------------------
    ----------------------------------- brackets -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = ";(", snippetType = "autosnippet" }, fmta("\\left(<>\\right)", { d(1, get_visual) })),
    s({ trig = ";[", snippetType = "autosnippet" }, fmta("\\left[<>\\right]", { d(1, get_visual) })),
    s({ trig = ";{", snippetType = "autosnippet" }, fmta("\\left\\{<>\\right\\}", { d(1, get_visual) })),
    --------------------------------------------------------------------------------
    ---------------------------------- maths mode ----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "m", dscr = "inline math mode" }, fmta("\\(<>\\)", { d(1, get_visual) })),
    s({ trig = "M", dscr = "display math mode" }, fmta([[ \[ <> \] ]], { d(1, get_visual) })),
    s({ trig = "t", dscr = "text" }, fmta([[ \text{<>} ]], { d(1, get_visual) })),
    --------------------------------------------------------------------------------
    ---------------------------------- maths font ----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "b", dscr = "mathbf" }, fmta("\\mathbf{<>}", { d(1, get_visual) })),
    s({ trig = "r" }, fmta("\\mathrm{<>}", { d(1, get_visual) })),
    s({ trig = "bb", dscr = "mathbb" }, fmta("\\mathbb{<>}", { d(1, get_visual) })),
    s({ trig = "c", dscr = "mathcal" }, fmta("\\mathcal{<>}", { d(1, get_visual) })),
    --------------------------------------------------------------------------------
    ---------------------------------- operations ----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "ff", dscr = "fraction" }, fmta("\\frac{<>}{<>}", { i(1, "numerator"), i(2, "denominator") })),
    s({ trig = "sq", dscr = "square root" }, fmta("\\sqrt{<>}", { d(1, get_visual) })),
    s({ trig = "d", dscr = "differential operator" }, t("\\operatorname{d}\\!")),
    s({ trig = "pd", dscr = "partial differential operator" }, t("\\partial\\!")),
    s({ trig = "df", dscr = "differential operator (fraction)" },
        fmta("\\frac{\\operatorname{d}\\! <>}{\\operatorname{d}\\! <>}", { i(1), i(2) })),
    s({ trig = "pdf", dscr = "pratial differential operator (fraction)" },
        fmta("\\frac{\\partial <>}{\\partial <>}", { i(1), i(2) })),
    s({ trig = "int" },
        fmta("\\int_{<>}^{<>} <> \\operatorname{d}\\! <>",
            { i(1), i(2), i(4, "integrable function"), i(3, "differential form") })),
    s({ trig = "inf", dscr = "expection" }, fmta("\\infty", {})),
    s({ trig = "expt", dscr = "expection" }, fmta("\\operatorname{E}\\left(<>\\right)", { d(1, get_visual) })),
    s({ trig = "cov", dscr = "covariance" }, fmta("\\operatorname{Cov}\\left(<>\\right)", { d(1, get_visual) })),
    --------------------------------------------------------------------------------
    ------------------------------ common descriptors ------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "bar", dscr = "bar" }, fmta("\\bar{<>}", { d(1, get_visual) })),
    s({ trig = "hat", dscr = "hat" }, fmta("\\hat{<>}", { d(1, get_visual) })),
    s({ trig = "tilde", dscr = "tilde" }, fmta("\\tilde{<>}", { d(1, get_visual) })),
    s({ trig = "op", dscr = "operatorname" }, fmta("\\operatorname{<>}", { d(1, get_visual) })),
    s({ trig = "tp", dscr = "transpose" }, fmta("^{\\mathrm{T}}", {})),
    --------------------------------------------------------------------------------
    -------------------------------- greek letters ---------------------------------
    --------------------------------------------------------------------------------
    s({ trig = ";a", snippetType = "autosnippet", dscr = "alpha" }, { t("\\alpha") }),
    s({ trig = ";b", snippetType = "autosnippet", dscr = "beta" }, { t("\\beta"), }),
    s({ trig = ";g", snippetType = "autosnippet", dscr = "gamma" }, { t("\\gamma"), }),
    s({ trig = ";G", snippetType = "autosnippet", dscr = "Gamma" }, { t("\\Gamma"), }),
    s({ trig = ";d", snippetType = "autosnippet", dscr = "delta" }, { t("\\delta"), }),
    s({ trig = ";D", snippetType = "autosnippet", dscr = "Delta" }, { t("\\Delta"), }),
    s({ trig = ";ep", snippetType = "autosnippet", dscr = "epsilon" }, { t("\\epsilon"), }),
    s({ trig = ";z", snippetType = "autosnippet", dscr = "zeta" }, { t("\\zeta"), }),
    s({ trig = ";et", snippetType = "autosnippet", dscr = "eta" }, { t("\\eta"), }),
    s({ trig = ";th", snippetType = "autosnippet", dscr = "theta" }, { t("\\theta"), }),
    s({ trig = ";Th", snippetType = "autosnippet", dscr = "Theta" }, { t("\\Theta"), }),
    s({ trig = ";l", snippetType = "autosnippet", dscr = "lambda" }, { t("\\lambda"), }),
    s({ trig = ";L", snippetType = "autosnippet", dscr = "Lambda" }, { t("\\Lambda"), }),
    s({ trig = ";m", snippetType = "autosnippet", dscr = "mu" }, { t("\\mu"), }),
    s({ trig = ";M", snippetType = "autosnippet", dscr = "Mu" }, { t("\\Mu"), }),
    s({ trig = ";n", snippetType = "autosnippet", dscr = "nu" }, { t("\\nu"), }),
    s({ trig = ";N", snippetType = "autosnippet", dscr = "Nu" }, { t("\\Nu"), }),
    s({ trig = ";x", snippetType = "autosnippet", dscr = "xi" }, { t("\\xi"), }),
    s({ trig = ";X", snippetType = "autosnippet", dscr = "Xi" }, { t("\\Xi"), }),
    s({ trig = ";r", snippetType = "autosnippet", dscr = "rho" }, { t("\\rho"), }),
    s({ trig = ";s", snippetType = "autosnippet", dscr = "sigma" }, { t("\\sigma"), }),
    s({ trig = ";S", snippetType = "autosnippet", dscr = "Sigma" }, { t("\\Sigma"), }),
    s({ trig = ";t", snippetType = "autosnippet", dscr = "tau" }, { t("\\tau"), }),
    s({ trig = ";ph", snippetType = "autosnippet", dscr = "phi" }, { t("\\phi"), }),
    s({ trig = ";Ph", snippetType = "autosnippet", dscr = "Phi" }, { t("\\Phi"), }),
    s({ trig = ";ps", snippetType = "autosnippet", dscr = "psi" }, { t("\\psi"), }),
    s({ trig = ";Ps", snippetType = "autosnippet", dscr = "Psi" }, { t("\\Psi"), }),
    s({ trig = ";o", snippetType = "autosnippet", dscr = "omega" }, { t("\\omega"), }),
    s({ trig = ";O", snippetType = "autosnippet", dscr = "Omega" }, { t("\\Omega"), }),
    --------------------------------------------------------------------------------
    ----------------------------------- matrices -----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "bm", dscr = "" },
        fmta([[
            \begin{bmatrix}
                <>
            \end{bmatrix}
        ]], { i(1, "") })
    ),
    s({ trig = "pm", dscr = "" },
        fmta([[
            \begin{pmatrix}
                <>
            \end{pmatrix}
        ]], { i(1, "") })
    ),
    --------------------------------------------------------------------------------
    ----------------------------- logical connectives ------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "fa", dscr = "forall" }, { t("\\forall\\,"), }),
    s({ trig = "ex", dscr = "exists" }, { t("\\exists\\:"), }),
    s({ trig = "nex", dscr = "nonexists" }, { t("\\exists!\\:"), }),
    --------------------------------------------------------------------------------
    ------------------------------------ cases -------------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "cases", dscr = "based on 'empheq' package" },
        fmta([[
            \begin{empheq}[left={\eqmath[r]{A}{<>}\empheqlbrace}]{alignat=2}
                &\eqmath[l]{B}{<>} &\qquad& \eqtext[l]{C}{<>} \\
            \end{empheq}
        ]], { i(1, "stuff to be classified"), i(2, "one case"), i(3, "condition") })
    ),
    --------------------------------------------------------------------------------
    ---------------------------------- hyperlinks ----------------------------------
    --------------------------------------------------------------------------------
    s({ trig = "hr" },
        fmta("\\href{<>}{<>}", { i(1, "url"), d(2, get_visual) })
    ),
}
