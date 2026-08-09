return {
	"HiPhish/jinja.vim",
	-- Deliberately not lazy-loaded. This plugin's own ftdetect is what maps
	-- *.jinja/*.j2 onto the `jinja` filetype (and compound ones like
	-- `html.jinja`), so `ft = "jinja"` would wait for a filetype that only it
	-- can produce. It is vimscript-only and does not register on startup.
	lazy = false,
}
