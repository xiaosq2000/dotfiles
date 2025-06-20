#!/usr/bin/env bash

# Script configuration
VERBOSE=${VERBOSE:-false}
PROTOCOL=${PROTOCOL:-trojan}
DEFAULT_PROXY_HOST="127.0.0.1"
DEFAULT_PROXY_PORT=1080
TIMEOUT=10
LOG_PREFIX="[Network Proxy] "

# Internationalization Support
# Using typeset -A to ensure ZSH compatibility for associative arrays
typeset -A TRANSLATIONS
TRANSLATIONS=(
    ["ERROR"]="错误"
    ["WARNING"]="警告"
    ["INFO"]="信息"
    ["DEBUG"]="调试"
    ["BASHRC_ALREADY_CONFIGURED"]="网络脚本已在 .bashrc 中配置。"
    ["BASHRC_ADDED"]="已将网络脚本添加到 .bashrc 以便自动加载。"
    ["BASHRC_BACKUP_CREATED"]="已为您的 .bashrc 文件创建备份。"
    ["BASHRC_NOT_FOUND"]="在您的主目录中未找到 .bashrc 文件。"
    ["ZSHRC_ALREADY_CONFIGURED"]="网络脚本已在 .zshrc 中配置。"
    ["ZSHRC_ADDED"]="已将网络脚本添加到 .zshrc 以便自动加载。"
    ["ZSHRC_BACKUP_CREATED"]="已为您的 .zshrc 文件创建备份。"
    ["ZSHRC_NOT_FOUND"]="在您的主目录中未找到 .zshrc 文件。"
    ["SCRIPT_NOT_FOUND"]="无法找到网络管理脚本文件本身。"
    ["SHELL_RC_ADDED"]="已添加到 Shell 配置文件。"
    ["NO_SHELL_RC_FOUND"]="未能找到 .bashrc 或 .zshrc 文件进行配置。"
    ["VPN_STATUS"]="VPN 服务状态"
    ["PROXY_ENV_VARS"]="代理环境变量"
    ["STOP_VPN"]="正在停止 VPN 客户端服务。"
    ["NETWORK_CHECK_FAILED"]="网络检查失败。您可能已离线。"
    ["TIMEOUT"]="超时"
    ["Public Network:"]="公共网络详情："
    ["Private Network:"]="私有网络详情："
    ["No public networking."]="无法确定公共 IP。您可能已离线。"
    ["This platform is not supported."]="此脚本不支持当前操作系统。"
    ["Make sure the VPN client is working on host."]="正在 WSL2/Docker 中运行。请确保代理客户端正在您的主机上运行。"
    ["Start the VPN client service."]="正在启动 VPN 客户端服务。"
    ["Set GNOME networking proxy settings."]="正在应用 GNOME 桌面代理设置。"
    ["Unset GNOME networking proxy settings."]="正在移除 GNOME 桌面代理设置。"
    ["Set environment variables and configure for specific programs."]="正在设置代理环境变量。"
    ["Unset environment variables."]="正在取消代理环境变量。"
    ["Set git global network proxy."]="正在应用 git 全局代理配置。"
    ["Unset git global network proxy."]="正在移除 git 全局代理配置。"
    ["The shell is using network proxy."]="代理在此 shell 会话中已激活。"
    ["The shell is NOT using network proxy."]="代理在此 shell 会话中未激活。"
    ["Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually."]="无法在 WSL2/Docker 中确定 VPN 状态。请手动检查主机。"
    ["Done!"]="完成！"
    ["If not working, wait a couple of seconds."]="代理设置已应用。如果无法连接，请稍等几秒后重试。"
    ["If still not working, you are suggested to execute following commands to print log and ask for help."]="如果问题仍然存在，请运行以下命令进行诊断并寻求帮助："
    ["Available handy commands for networking proxy"]="网络代理助手 - 可用命令："
    ["FAILED_DETECT_PUBLIC_IP"]="在 {} 秒内检测公共 IP 失败。请检查您的网络连接。"
    ["Failed to determine WSL host IP address."]="未能确定 WSL 主机 IP 地址。无法设置代理。"
    ["Failed to get private IP"]="获取私有 IP 失败。"
    ["An argument, the port number, should be given."]="需要提供端口号作为参数。"
    ["ufw is active."]="UFW 防火墙是活动的。"
    ["ufw is inactive."]="UFW 防火墙是关闭的。"
    ["port {} is not specified in the firewall rules and may not be allowed to use."]="端口 {} 未在防火墙规则中指定，可能不允许使用。"
    ["port {} is not in use."]="端口 {} 未被使用。"
    ["port {} is unavailable."]="端口 {} 不可用。"
)

_has() {
  command -v "$1" 1>/dev/null 2>&1
}

# Terminal colors with fallback - Bash and ZSH compatible
_setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        BOLD="$(tput bold 2>/dev/null || echo '')"
        GREY="$(tput setaf 0 2>/dev/null || echo '')"
        RED="$(tput setaf 1 2>/dev/null || echo '')"
        GREEN="$(tput setaf 2 2>/dev/null || echo '')"
        YELLOW="$(tput setaf 3 2>/dev/null || echo '')"
        BLUE="$(tput setaf 4 2>/dev/null || echo '')"
        MAGENTA="$(tput setaf 5 2>/dev/null || echo '')"
        RESET="$(tput sgr0 2>/dev/null || echo '')"
    else
        BOLD=""
        GREY=""
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        MAGENTA=""
        RESET=""
    fi
}

# Detect system locale, allowing override with FORCE_LANG
_detect_language() {
    if [[ -n "${FORCE_LANG}" ]]; then
        # Use forced language if set
        case "$FORCE_LANG" in
            zh_CN* | zh_SG*) echo "zh_CN" ;;
            *) echo "en_US" ;; # Default to English if FORCE_LANG is set but not Chinese
        esac
    else
        # Fallback to system LANG variable
        local lang=${LANG:-en_US.UTF-8}
        case "$lang" in
            zh_CN* | zh_SG*) echo "zh_CN" ;;
            *) echo "en_US" ;;
        esac
    fi
}

# Translation function with fallback - Bash and ZSH compatible
_translate() {
    local text="$1"
    local language=$(_detect_language)

    if [[ "$language" == "zh_CN" ]]; then
        echo "${TRANSLATIONS[$text]:-$text}"
    else
        # In English mode, the key is the message itself.
        # We replace the key name with the English text from the array if it exists,
        # otherwise we fall back to the key name itself.
        # This allows using descriptive keys or the English text directly.
        local key_as_text=${text}
        case "$text" in
            BASHRC_*) key_as_text=${TRANSLATIONS[$text]} ;;
            ZSHRC_*) key_as_text=${TRANSLATIONS[$text]} ;;
            # Add other key prefixes if needed
        esac
        # Fallback to text if not found
        echo "${key_as_text:-$text}"
    fi
}


# Logging functions - ZSH compatible
_error() { printf '%s\n' "${LOG_PREFIX}${BOLD}${RED}$(_translate 'ERROR'):${RESET} $*" >&2; }
_warning() { printf '%s\n' "${LOG_PREFIX}${BOLD}${YELLOW}$(_translate 'WARNING'):${RESET} $*"; }
_info() { printf '%s\n' "${LOG_PREFIX}${BOLD}${GREEN}$(_translate 'INFO'):${RESET} $*"; }
_debug() {
    [[ $VERBOSE == true ]] && printf '%s\n' "${LOG_PREFIX}${BOLD}${GREY}$(_translate 'DEBUG'):${RESET} $*"
}

# Get script path - ZSH compatible
_get_script_path() {
    if [ -n "$BASH_VERSION" ]; then
        echo "$(realpath "${BASH_SOURCE[0]}")"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "${${(%):-%x}:A}"
    else
        echo "Unsupported shell type"
        return 1
    fi
}

check_public_ip() {
    local timeout=${1:-1} # Default timeout is 1 second
    local ipinfo
    ipinfo=$(curl --silent --max-time "$timeout" ipinfo.io)

    if [ $? -ne 0 ]; then
        local error_msg=$(_translate 'FAILED_DETECT_PUBLIC_IP')
        _warning "${error_msg//\{\}/$timeout}" # Replace {} with timeout value
        return 1
    fi

    if [ -z "$ipinfo" ]; then
        # Handle case where curl succeeds but returns empty output (less likely but possible)
        local error_msg=$(_translate 'FAILED_DETECT_PUBLIC_IP')
        _error "${error_msg//\{\}/$timeout}" # Replace {} with timeout value
        return 1
    fi

    echo -e "${MAGENTA}$(_translate 'Public Network:')${RESET}\n${INDENT}$(echo "$ipinfo" | grep --color=never -e '\"ip\"' -e '\"city\"' | sed 's/^[ \t]*//' | awk '{print}' ORS=' ')"
    return 0
}

check_private_ip() {
    local private_ip
    if ! private_ip=$(hostname -I 2>/dev/null | awk '{ print $1 }'); then
        _error "$(_translate 'Failed to get private IP')"
        return 1
    fi

    echo -e "${MAGENTA}$(_translate 'Private Network:')${RESET}\n${INDENT}\"ip\": \"${private_ip}\","
    return 0
}

# Get proxy configuration based on platform
_get_proxy_config() {
    if [[ -f "/.dockerenv" ]]; then
        printf -v "$1" "host.docker.internal"
        printf -v "$2" "%s" "${DEFAULT_PROXY_PORT}"
        _warning "$(_translate 'Make sure the VPN client is working on host.')"
    elif [[ $(uname -r) =~ WSL2 ]]; then
        local host_ip
        host_ip=$(ip route show | grep -i default | awk '{ print $3}')
        if [[ -z "$host_ip" ]]; then
            _error "$(_translate 'Failed to determine WSL host IP address.')"
            return 1
        fi
        printf -v "$1" "%s" "$host_ip"
        printf -v "$2" "%s" "${DEFAULT_PROXY_PORT}"
        _warning "$(_translate 'Make sure the VPN client is working on host.')"
    elif [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]]; then
        printf -v "$1" "%s" "${DEFAULT_PROXY_HOST}"
        printf -v "$2" "%s" "${DEFAULT_PROXY_PORT}"
    else
        _error "$(_translate 'This platform is not supported.')"
        return 1
    fi

    return 0
}

check_port_availability() {
    if [[ -z $1 ]]; then
        _error "$(_translate 'An argument, the port number, should be given.')"
        return 1;
    fi
    if _has ufw; then
        if [[ $(sudo ufw status | head -n 1 | awk '{ print $2;}') == "active" ]]; then
            _info "$(_translate 'ufw is active.')";
            if [[ -z $(sudo ufw status | grep "$1") ]]; then
                local msg=$(_translate 'port {} is not specified in the firewall rules and may not be allowed to use.')
                _warning "${msg//\{\}/$1}"
            else
                sudo ufw status | grep "$1"
            fi
        else
            _info "$(_translate 'ufw is inactive.')";
        fi
    fi
    if [[ -z $(sudo lsof -i:$1) ]]; then
        local msg=$(_translate 'port {} is not in use.')
        _info "${msg//\{\}/$1}"
    else
        local msg=$(_translate 'port {} is unavailable.')
        _error "${msg//\{\}/$1}"
    fi
}

# Internal helper to set common proxy environment variables
_set_proxy_env_vars() {
    local proxy_host="$1"
    local proxy_port="$2"
    export http_proxy="http://${proxy_host}:${proxy_port}"
    export https_proxy="http://${proxy_host}:${proxy_port}"
    export ftp_proxy="ftp://${proxy_host}:${proxy_port}"
    export socks_proxy="socks5://${proxy_host}:${proxy_port}"
    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$https_proxy"
    export FTP_PROXY="$ftp_proxy"
    export SOCKS_PROXY="$socks_proxy"
    export no_proxy="localhost,127.0.0.0/8,::1,host.docker.internal,.um.edu.mo"
    export NO_PROXY="${no_proxy}"
}

# Internal helper to unset common proxy environment variables
_unset_proxy_env_vars() {
    unset {http,https,ftp,socks,all,no}_proxy
    unset {HTTP,HTTPS,FTP,SOCKS,ALL,NO}_PROXY
}

# Set proxy environment variables for current shell only
set_local_proxy() {
    local proxy_host proxy_port
    if ! _get_proxy_config proxy_host proxy_port; then
        return 1
    fi

    _set_proxy_env_vars "$proxy_host" "$proxy_port"

    # Set git proxy for current shell only
    # Reference: https://git-scm.com/docs/git-config#ENVIRONMENT
    export GIT_CONFIG_COUNT=2
    export GIT_CONFIG_KEY_0="http.proxy"
    export GIT_CONFIG_VALUE_0="$http_proxy"
    export GIT_CONFIG_KEY_1="https.proxy"
    export GIT_CONFIG_VALUE_1="$https_proxy"

    # _info "$(_translate 'Done!')"
}

# Unset proxy environment variables for current shell only
unset_local_proxy() {
    _unset_proxy_env_vars

    # Unset git proxy config for current shell
    unset GIT_CONFIG_COUNT
    unset GIT_CONFIG_{KEY,VALUE}_{0..1}
}

# Set proxy configuration
set_proxy() {
    local proxy_host proxy_port
    if ! _get_proxy_config proxy_host proxy_port; then
        return 1
    fi

    # Set environment variables
    _debug "$(_translate 'Set environment variables and configure for specific programs.')"
    _set_proxy_env_vars "$proxy_host" "$proxy_port"

    # Configure git proxy
    _debug "$(_translate 'Set git global network proxy.')"
    if command -v git >/dev/null 2>&1; then
        git config --global http.proxy "http://${proxy_host}:${proxy_port}"
        git config --global https.proxy "http://${proxy_host}:${proxy_port}"
    fi

    # Configure GNOME proxy if applicable
    if [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]] && command -v dconf >/dev/null 2>&1; then
        _debug "$(_translate 'Set GNOME networking proxy settings.')"
        dconf write /system/proxy/mode "'manual'"
        for protocol in http https ftp socks; do
            dconf write "/system/proxy/${protocol}/host" "'${proxy_host}'"
            dconf write "/system/proxy/${protocol}/port" "${proxy_port}"
        done
        # Format no_proxy for dconf (GVariant string array)
        local formatted_no_proxy
        formatted_no_proxy=$(echo "$no_proxy" | sed "s/,/','/g")
        formatted_no_proxy="['${formatted_no_proxy}']"
        dconf write /system/proxy/ignore-hosts "${formatted_no_proxy}"
    fi
    # _info "$(_translate 'Done!')"
    _info "$(_translate 'If not working, wait a couple of seconds.')"
    _info "$(_translate 'If still not working, you are suggested to execute following commands to print log and ask for help.')"
    echo -e "${INDENT}${GREEN}${BOLD}\$${RESET} VERBOSE=true check_proxy_status \n${INDENT}${GREEN}${BOLD}\$${RESET} check_public_ip"
}

# Unset proxy configuration
unset_proxy() {
    # Unset environment variables
    _debug "$(_translate 'Unset environment variables.')"
    _unset_proxy_env_vars

    # Unset git proxy configuration
    _debug "$(_translate 'Unset git global network proxy.')"
    if command -v git >/dev/null 2>&1; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
    fi

    # Reset GNOME proxy if applicable
    if [[ $(lsb_release -d 2>/dev/null) =~ Ubuntu ]] && command -v dconf >/dev/null 2>&1; then
        _debug "$(_translate 'Unset GNOME networking proxy settings.')"
        dconf write /system/proxy/mode "'none'"
    fi

    # _info "$(_translate 'Done!')"
}

# Check proxy status
check_proxy_status() {
    local proxy_env
    proxy_env=$(env | grep -i proxy)

    if [[ -n $proxy_env ]]; then
        _info "$(_translate 'The shell is using network proxy.')"
    else
        _info "$(_translate 'The shell is NOT using network proxy.')"
    fi
    echo

    check_public_ip

    if [[ $VERBOSE == true ]]; then
        echo "$(_translate 'PROXY_ENV_VARS'):"
        echo "$proxy_env" | while read -r line; do
            echo "${INDENT}${line}"
        done
        echo

        echo -e "$(_translate 'VPN_STATUS'): ${RESET}"
        if [[ $(uname -r) =~ WSL2 ]]; then
            _warning "$(_translate 'Unknown. For WSL2, the VPN client is probably running on the host machine. Please check manually.')"
        elif [[ -f /.dockerenv ]]; then
            _warning "$(_translate 'Unknown. For a Docker container, the VPN client is probably running on the host machine. Please check manually.')"
        elif command -v systemctl >/dev/null 2>&1; then
            echo "${INDENT}$(systemctl is-active "sing-box-${PROTOCOL}.service")"
        else
            _warning "$(_translate 'Cannot determine VPN status - systemctl not available')"
        fi
        echo
    fi
}

# Generic function to configure shell RC files
_network_management_configure_shell_rc() {
    local rc_file="$1"
    local rc_name="$2"
    local translate_prefix="$3"

    local script_path
    script_path=$(_get_script_path) || return 1

    if [[ ! -f "$script_path" ]]; then
        _error "$(_translate 'SCRIPT_NOT_FOUND')"
        return 1
    fi

    if [[ ! -f "$rc_file" ]]; then
        _error "$(_translate "${translate_prefix}_NOT_FOUND")"
        return 1
    fi

    # Create backup if it doesn't exist
    local backup="${rc_file}.backup"
    if [[ ! -f "$backup" ]]; then
        cp "$rc_file" "$backup"
        _info "$(_translate "${translate_prefix}_BACKUP_CREATED"): ${backup}"
    fi

    # Check if source line already exists
    local source_line="[ -f ${script_path} ] && source ${script_path}"
    if grep -q "^[[:space:]]*\[.*\].*&&.*source[[:space:]]*${script_path}" "$rc_file"; then
        _info "$(_translate "${translate_prefix}_ALREADY_CONFIGURED")"
        return 0
    fi

    # Add newline if the file doesn't end with one
    [[ -s "$rc_file" && -z "$(tail -c1 "$rc_file")" ]] || echo "" >> "$rc_file"

    {
        echo "# Network proxy management configuration"
        echo "$source_line"
        echo ""
    } >> "$rc_file"

    _info "$(_translate "${translate_prefix}_ADDED")"

    echo
    _info "$(_translate 'To apply changes, run:')"
    echo -e "\n${INDENT}$ source ${rc_file}"
}

# Function to configure bashrc
_network_management_configure_bashrc() {
    _network_management_configure_shell_rc "${HOME}/.bashrc" "bashrc" "BASHRC"
}

# Function to configure zshrc
_network_management_configure_zshrc() {
    _network_management_configure_shell_rc "${HOME}/.zshrc" "zshrc" "ZSHRC"
}

# Function to configure all available shell RC files
_network_management_configure_all_shells() {
    local configured=false

    if [[ -f "${HOME}/.bashrc" ]]; then
        _network_management_configure_bashrc
        configured=true
    fi

    if [[ -f "${HOME}/.zshrc" ]]; then
        _network_management_configure_zshrc
        configured=true
    fi

    if [[ "$configured" == false ]]; then
        _error "$(_translate 'NO_SHELL_RC_FOUND')"
        return 1
    fi

    return 0
}

# Main script initialization
_setup_colors
INDENT='    '
if [[ $VERBOSE == "true" ]]; then
    # Show available commands
    echo "$(_translate "Available handy commands for networking proxy")"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} set_proxy       # Global proxy with service management"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} unset_proxy     # Remove global proxy config"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} set_local_proxy # Set proxy for current shell only"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} unset_local_proxy # Remove current shell proxy"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_private_ip"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_public_ip"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_proxy_status"
    echo
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} network_management_configure_all_shells"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} network_management_configure_zshrc"
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} network_management_configure_bashrc"
    echo
    echo "${INDENT}${GREEN}${BOLD}\$${RESET} check_port_availability <PORT>"
fi
