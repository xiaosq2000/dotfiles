#!/bin/bash
# Exercise the deployed configs with a working, broken and absent pixi zsh.
# Nothing under the caller's home is changed, and tmux uses a private server.
set -euo pipefail

config_dir=${1:?usage: check-shell-launchers.sh CONFIG_DIR [nvim|tmux|all]}
check=${2:-all}
test_dir=$(mktemp -d)
test_home="$test_dir/home"
mkdir -p "$test_home/.pixi/bin" "$test_home/.pixi/envs/zsh/bin"
socket="$test_dir/tmux.sock"
cleanup() {
    if [[ -S $socket ]]; then tmux -S "$socket" kill-server 2>/dev/null || true; fi
    rm -rf "$test_dir"
}
trap cleanup EXIT

export TEST_HOME="$test_home" TEST_CONFIG_DIR="$config_dir"
binary="$test_home/.pixi/envs/zsh/bin/zsh"
launcher="$test_home/.pixi/bin/zsh"
# This fixture models the trampoline overwriting a real Python activation.
cat > "$launcher" <<'SH'
#!/bin/sh
export CONDA_PREFIX="$HOME/.pixi/envs/zsh" CONDA_SHLVL=1
export PATH="$CONDA_PREFIX/bin:$PATH"
exec "$CONDA_PREFIX/bin/zsh" "$@"
SH
chmod +x "$launcher"
ln -s /usr/bin/zsh "$binary"

if [[ $check == nvim || $check == all ]]; then
    cat > "$test_dir/check.lua" <<'LUA'
local ok, err = pcall(function()
    local home = vim.env.TEST_HOME
    vim.env.HOME = home
    vim.env.SHELL = home .. "/.pixi/bin/zsh"
    vim.env.CONDA_PREFIX = home .. "/active-python"
    vim.env.CONDA_SHLVL = "2"
    vim.env.VIRTUAL_ENV = home .. "/active-venv"
    vim.env.PATH = vim.env.CONDA_PREFIX .. "/bin:/usr/bin:/bin"
    local expected = table.concat({
        vim.env.CONDA_PREFIX, vim.env.CONDA_SHLVL, vim.env.VIRTUAL_ENV, vim.env.PATH,
    }, "\n") .. "\n"
    local binary = home .. "/.pixi/envs/zsh/bin/zsh"
    local function check(expected_shell)
        -- Each case starts as an editor inheriting the trampoline in $SHELL.
        vim.o.shell = vim.env.SHELL
        vim.o.shell = dofile(vim.env.TEST_CONFIG_DIR .. "/nvim/lua/core/shell.lua")
        assert(vim.o.shell == expected_shell, vim.o.shell)
        local output = vim.fn.system([[printf '%s\n' "$CONDA_PREFIX" "$CONDA_SHLVL" "$VIRTUAL_ENV" "$PATH"]])
        assert(vim.v.shell_error == 0, "shell command failed")
        assert(output == expected, "shell changed the active environment: " .. output)
    end
    check(binary)
    -- Executable is insufficient: model a missing dependency behind it.
    assert(os.remove(binary))
    vim.fn.writefile({ "#!/bin/sh", "exit 127" }, binary)
    assert(vim.fn.setfperm(binary, "rwx------") == 1)
    check("/bin/sh")
    assert(os.remove(binary))
    check("/bin/sh")
    print("Neovim preserves the environment and rejects broken or absent zsh")
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
LUA
    NVIM_LOG_FILE="$test_dir/nvim.log" timeout 30 nvim --headless -u NONE -i NONE -n -c "luafile $test_dir/check.lua"
fi

if [[ $check == tmux || $check == all ]]; then
    # Read the shell selection from the deployed config without loading tpm or
    # changing any existing tmux server. Check the selected shell and a new pane.
    sed '/^# A shortcut to source config file/,$d' "$config_dir/tmux/tmux.conf" > "$test_dir/tmux.conf"
    run_tmux() { env HOME="$test_home" SHELL="$launcher" tmux -S "$socket" "$@"; }
    check_tmux() {
        local expected=$1 marker="$test_dir/pane-started"
        socket="$test_dir/tmux-$RANDOM.sock"
        run_tmux -f "$test_dir/tmux.conf" new-session -d -s test 'sleep 30'
        test "$(run_tmux show-options -gv default-shell)" = "$expected"
        # A fresh window without a command starts the selected shell itself.
        run_tmux new-window -t test -n check
        run_tmux send-keys -t test:check "printf started > '$marker'" Enter
        for _ in {1..50}; do
            [[ -f $marker ]] && break
            sleep 0.1
        done
        test "$(cat "$marker")" = started
        run_tmux kill-server
        rm "$marker"
    }
    rm -f "$binary"
    ln -s /usr/bin/zsh "$binary"
    check_tmux "$launcher"
    rm "$binary"
    printf '#!/bin/sh\nexit 127\n' > "$binary"
    chmod +x "$binary"
    check_tmux /bin/sh
    rm "$binary" "$launcher"
    check_tmux /bin/sh
    echo 'tmux opens panes with working, broken and absent pixi launchers'
fi
