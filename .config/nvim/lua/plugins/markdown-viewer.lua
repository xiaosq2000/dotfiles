-- Todo: offer different scheme for lazy.nvim instead.

local function is_docker()
	local f = io.open("/.dockerenv", "r")
	if f ~= nil then
		io.close(f)
		return true
	end
	return os.getenv("container") == "docker"
end

if not is_docker() then
	return {
		"fmorroni/peek.nvim",
		branch = "callouts",
		event = { "VeryLazy" },
		build = "deno task --quiet build:fast",
		config = function()
			require("peek").setup({ app = "browser", theme = "light" })
			vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
			vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
		end,
	}
end

return {}
