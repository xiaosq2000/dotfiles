-- return {
--     "richwomanbtc/overleaf.nvim",
--     config = function()
--         require("overleaf").setup()
--     end,
--     build = "cd node && npm install",
-- }
-- return {
-- 	dir = "/home/shuqixiao/Projects/overleaf.nvim",
-- 	name = "overleaf.nvim",
-- 	build = "cd node && npm install",
-- 	config = function()
-- 		require("overleaf").setup({
-- 			log_level = "debug", -- useful for verifying linux cookie flow
-- 		})
-- 	end,
-- }
return {
	"xiaosq2000/overleaf.nvim",
	branch = "fix/connect",
	config = function()
		require("overleaf").setup()
	end,
	build = "cd node && npm install",
}
