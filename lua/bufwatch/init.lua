local events = require("bufwatch.events")
local ui = require("bufwatch.ui")

local M = {}

function M.open_stats_window()
	ui.open_stats_window()
end

function M.on_event(event)
	events.handle(event)
end

vim.api.nvim_create_user_command("BufWatchStats", function()
	require("bufwatch").open_stats_window()
end, {})

require("bufwatch.autocmds")

return M
