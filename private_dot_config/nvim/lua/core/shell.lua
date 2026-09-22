-- Commands inherit the editor's Python environment. The pixi trampoline
-- overwrites it, and zsh -c reads no .zshrc to undo those changes, so run the
-- binary directly. See ~/.sh_utils/CAVEATS.md.
local pixi_zsh = vim.env.HOME .. "/.pixi/envs/zsh/bin/zsh"
if vim.fn.executable(pixi_zsh) == 1 then
	vim.fn.system({ pixi_zsh, "-fc", ":" })
	if vim.v.shell_error == 0 then
		return pixi_zsh
	end
end

-- $SHELL may still name a broken pixi trampoline from an existing session.
return "/bin/sh"
