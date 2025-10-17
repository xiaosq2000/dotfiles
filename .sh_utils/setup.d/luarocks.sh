#!/usr/bin/env bash
# shellcheck source=../lib/ui.sh
source "$HOME/.sh_utils/lib/ui.sh"
glibc_version=$(getconf GNU_LIBC_VERSION | cut -d' ' -f2)
glibc_num=$(echo "$glibc_version" | awk -F. '{print $1 * 100 + $2}')
# Set luarocks version based on glibc version
if ((glibc_num > 238)); then
    LUAROCKS_VERSION="3.11.1"
elif ((glibc_num <= 238)) && ((glibc_num > 231)); then
    LUAROCKS_VERSION="3.8.0"
else
    LUAROCKS_VERSION="3.7.0"
fi
export XDG_PREFIX_HOME="$HOME/.local"
info "Installing the luarocks ${LUAROCKS_VERSION}"
wget -q "https://luarocks.github.io/luarocks/releases/luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip"
unzip -qq "luarocks-${LUAROCKS_VERSION}-linux-x86_64.zip"
cp luarocks-${LUAROCKS_VERSION}-linux-x86_64/luarocks* ${XDG_PREFIX_HOME}/bin
rm -r luarocks-${LUAROCKS_VERSION}-linux-x86_64*
# Check
if [ $? -eq 0 ]; then
    completed "luarocks version: $LUAROCKS_VERSION"
else
    error "Failed to install luarocks $LUAROCKS_VERSION"
    exit 1
fi
