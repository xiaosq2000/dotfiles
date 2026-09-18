--- Environment facts that plugin specs branch on.
--- Computed once so specs stay declarative.
local M = {}

--- True when nvim is running as kitty's scrollback pager, where most of the
--- editing stack is dead weight and some of it actively breaks the pager UI.
M.kitty_scrollback = vim.env.KITTY_SCROLLBACK_NVIM == "true"

--- A tmux pane inside kitty is still a tmux pane: tmux owns the splits, so it
--- wins the <C-hjkl> navigation keys.
M.in_tmux = vim.env.TMUX ~= nil
M.in_kitty = vim.env.KITTY_WINDOW_ID ~= nil and not M.in_tmux

return M
