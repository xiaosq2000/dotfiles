-- Seamless <C-hjkl> movement between nvim splits and the surrounding
-- multiplexer's panes. Exactly one navigator may own those keys, so the
-- multiplexer actually in use is detected at startup.
--
-- The kitty side additionally needs these lines in kitty.conf, without which
-- kitty swallows <C-hjkl> and nvim never sees them:
--   map --when-focus-on var:IS_VIM=true ctrl+h
--   map --when-focus-on var:IS_VIM=true ctrl+j
--   map --when-focus-on var:IS_VIM=true ctrl+k
--   map --when-focus-on var:IS_VIM=true ctrl+l
local env = require("core.env")

return {
	{
		"christoomey/vim-tmux-navigator",
		cond = env.in_tmux,
		cmd = {
			"TmuxNavigateLeft",
			"TmuxNavigateDown",
			"TmuxNavigateUp",
			"TmuxNavigateRight",
			"TmuxNavigatePrevious",
		},
		keys = {
			{ "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left" },
			{ "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down" },
			{ "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up" },
			{ "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right" },
			{
				"<c-\\>",
				"<cmd>TmuxNavigatePrevious<cr>",
				desc = "Navigate to previous pane",
			},
		},
	},
	{
		"knubie/vim-kitty-navigator",
		cond = env.in_kitty,
		-- Cannot be lazy-loaded on `keys`: kitty only forwards <C-hjkl> once the
		-- plugin has set IS_VIM=true, so the trigger would never fire. VeryLazy
		-- keeps its blocking `kitten @` call (~17ms) off the startup path while
		-- still setting the variable well before the first navigation.
		event = "VeryLazy",
	},
}
