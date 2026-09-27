-- auto-complete
return {
	"saghen/blink.cmp",
	dependencies = {
		{ "rafamadriz/friendly-snippets" },
		"L3MON4D3/LuaSnip",
		{
			"micangl/cmp-vimtex",
			dependencies = { "saghen/blink.compat", version = "*" },
		},
	},

	-- A release tag, because releases ship the prebuilt fuzzy matcher.
	version = "1.*",

	---@module 'blink.cmp'
	---@type blink.cmp.Config
	opts = {
		keymap = {
			preset = "default",
		},
		cmdline = {
			keymap = {
				preset = "cmdline",
			},
			completion = {
				menu = {
					auto_show = true,
				},
			},
		},
		term = {
			keymap = {
				preset = "enter",
			},
		},

		completion = {
			list = { selection = { preselect = false, auto_insert = true } },
			trigger = { show_in_snippet = false },
		},

		appearance = {
			-- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
			-- Adjusts spacing to ensure icons are aligned
			nerd_font_variant = "mono",
		},

		snippets = {
			preset = "luasnip",
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer", "vimtex" },
			providers = {
				path = {
					opts = {
						show_hidden_files_by_default = true,
					},
				},
				vimtex = {
					name = "vimtex",
					module = "blink.compat.source",
					score_offset = 100,
				},
			},
		},
	},
	opts_extend = { "sources.default" },
}
