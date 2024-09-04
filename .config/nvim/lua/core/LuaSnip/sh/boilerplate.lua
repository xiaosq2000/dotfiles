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
    s(
        {
            trig = "safety",
            dscr =
            [[-e: This option causes the bash script to exit immediately if any command exits with a non-zero status code, unless the command is part of a conditional expression or is followed by a || operator.
-u: This option treats unset variables as an error and causes the script to exit if an unset variable is encountered.
-o pipefail: This option sets the exit status of a pipeline to the rightmost non-zero exit status of any command in the pipeline. It means that if any command in a pipeline fails, the entire pipeline is considered to have failed.
]]
        },
        fmta([[
        set -euo pipefail

        ]], {})),
    s({ trig = "logging" },
        fmta([[
INDENT='    '
BOLD="$(tput bold 2>>/dev/null || printf '')"
GREY="$(tput setaf 0 2>>/dev/null || printf '')"
UNDERLINE="$(tput smul 2>>/dev/null || printf '')"
RED="$(tput setaf 1 2>>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>>/dev/null || printf '')"
MAGENTA="$(tput setaf 5 2>>/dev/null || printf '')"
RESET="$(tput sgr0 2>>/dev/null || printf '')"
error() {
	printf '%s\n' "${BOLD}${RED}ERROR:${RESET} $*" >>&2
}
warning() {
	printf '%s\n' "${BOLD}${YELLOW}WARNING:${RESET} $*"
}
info() {
	printf '%s\n' "${BOLD}${GREEN}INFO:${RESET} $*"
}
debug() {
	printf '%s\n' "${BOLD}${GREY}DEBUG:${RESET} $*"
}

        ]], {})),
    s(
        {
            trig = "arguments",
        },
        fmta([=[
usage() {
	printf "%s\n" \
		"Usage: " \
		"${INDENT}$0 [option]" \
		"" \
        "Some descriptions."
    printf "%s\n" \
		"Options: " \
		"${INDENT}-h, --help" \
        ""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
    -f | --flag)
		flag=true
		shift
		;;
	*)
		error "Unknown argument: $1"
		usage
		;;
	esac
done
        ]=], {})),
    s(
        {
            trig = "script_dir",
        },
        fmta([=[
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>>/dev/null && pwd)

        ]=], {})),
    s(
        {
            trig = "source_envfile",
        },
        fmta([=[
set -o allexport && source ${env_file} && set +o allexport
        ]=], {})),
}