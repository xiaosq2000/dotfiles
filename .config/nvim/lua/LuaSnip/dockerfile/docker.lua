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
    s({trig="apt"}, fmta([[
sudo apt-get update && sudo apt-get install -qy --no-install-recommends \
<> && \
sudo rm -rf /var/lib/apt/lists/* && \
    ]], {i(1, "packages")})),
    s({ trig = "build-local" }, fmta([[
# build & install <>
ARG <>_VERSION
COPY --chown=${DOCKER_USER}:${DOCKER_USER} ./downloads/<>-${<>_VERSION}.tar.gz .
RUN mkdir <>-${<>_VERSION} && tar -zxf <>-${<>_VERSION}.tar.gz --strip-component=1 -C <>-${<>_VERSION} && \
    cd <>-${<>_VERSION} && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build --prefix ${XDG_PREFIX_HOME} && \
    cd .. && rm -r <>*
    ]],
        { i(1, "eigen"), i(2, "EIGEN"), rep(1), rep(2), rep(1), rep(2), rep(1), rep(2), rep(1), rep(2), rep(1), rep(2),
            rep(1) })),
    s({ trig = "build-git" }, fmta([[
# build & install <>
ARG <>_GIT_REFERENCE
RUN git clone --config http.proxy="${http_proxy}" --config https.proxy="${https_proxy}" "<>" <> && \
    cd <> && \
    git checkout ${<>_GIT_REFERENCE} && \
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=17 && \
    cmake --build build -j ${COMPILE_JOBS} && \
    cmake --install build --prefix ${XDG_PREFIX_HOME} && \
    rm -r <>*
    ]],
        { i(1, "eigen"), i(2, "EIGEN"), i(3, "url"), rep(1), rep(1), rep(2), rep(1) })),
}
