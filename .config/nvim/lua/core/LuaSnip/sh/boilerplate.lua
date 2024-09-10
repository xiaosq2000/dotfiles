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
completed() {
	printf '%s\n' "${BOLD}${GREEN}✓${RESET} $*"
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
}
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
    --flag)
		flag=true
		shift 1
		;;
	--foo)
		foo="$2"
		shift 2
		;;
	*)
		error "Unknown argument: $1"
		usage
        exit 1
		;;
	esac
done

good_foo=$(
	IFS=" "
	for x in $SUPPORTED_FOO; do
		if [[ "$x" = "$foo" ]]; then
			printf 1
			break
		fi
	done
)
if [[ "${good_foo}" != "1" ]]; then
	error "foo=$foo is not supported yet."
	exit 1
fi
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
    s(
        {
            trig = "sudo",
        },
        fmta([=[
if [[ $(id -u) -ne 0 ]]; then
	error "The script needs root privilege to run. Try again with sudo."
	exit 1
fi
        ]=], {})),
    s(
        {
            trig = "has",
        },
        fmta([=[
has() {
    command -v "$1" 1>>/dev/null 2>>&1
}
        ]=], {})),
    s(
        {
            trig = "check_port_availability",
        },
        fmta([=[
check_port_availability() {
    if [[ -z $1 ]]; then
        error "An argument, the port number, should be given."
        return 1;
    fi
    if [[ $(sudo ufw status | head -n 1 | awk '{ print $2;}') == "active" ]]; then
        info "ufw is active.";
        if [[ -z $(sudo ufw status | grep "$1") ]]; then
            warning "port $1 is not specified in the firewall rules and may not be allowed to use.";
        else
            sudo ufw status | grep "$1"
        fi
    else
        info "ufw is inactive.";
    fi
    if [[ -z $(sudo lsof -i:$1) ]]; then
        info "port $1 is not in use.";
    else
        error "port $1 is ${BOLD}unavaiable${RESET}.";
    fi
}
        ]=], {})),
    s({ trig = "download" }, fmta([=[
wget_urls=()
wget_paths=()
_append_to_list() {
	# $1: flag
	if [ -z "$(eval echo "\$$1")" ]; then
		warning "$1 is unset. Failed to append to the downloading list."
		return 0
	fi
	# $2: url
	url="$2"
	# $3: filename
	if [ -z "$3" ]; then
		filename=$(basename "$url")
	else
		filename="$3"
	fi
	if [ ! -f "${downloads_dir}/${filename}" ]; then
		wget_paths+=("${downloads_dir}/${filename}")
		wget_urls+=("$url")
	fi
}
_wget_all() {
	for i in "${!wget_urls[@]}"; do
		wget "${wget_urls[i]}" -q -c --show-progress -O "${wget_paths[i]}"
	done
}
_download_everything() {
	# a wrapper of the function "wget_all"
	if [ ${#wget_urls[@]} = 0 ]; then
		debug "No download tasks."
	else
		debug "${#wget_urls[@]} files to download:"
		(
			IFS=$'\n'
			echo "${wget_urls[*]}"
		)
		_wget_all
	fi
}
    ]=], {}))

}
