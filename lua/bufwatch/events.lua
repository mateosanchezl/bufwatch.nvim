local project = require("bufwatch.project")
local state = require("bufwatch.state")
local timer = require("bufwatch.timer")

local M = {}

local function is_real_file(bufnr)
	if vim.bo[bufnr].buftype ~= "" then
		return false
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return false
	end

	return true
end

local function on_buf_enter(event)
	local bufnr = event.buf or 0
	if not is_real_file(bufnr) then
		return
	end

	local file_data = project.register_file(bufnr)
	timer.start(file_data)
end

local function on_buf_leave()
	timer.sync_elapsed_time()
	state.reset_current_file_path()
end

local function on_vim_quit()
	timer.sync_elapsed_time()
	state.persist()
end

local function on_vim_enter()
	if next(state.get_projects()) == nil then
		state.load()
	end
end

function M.handle(event)
	local e = event.event
	if e == "BufEnter" or e == "FocusGained" then
		on_buf_enter(event)
	elseif e == "BufLeave" or e == "FocusLost" then
		on_buf_leave()
	elseif e == "VimEnter" then
		on_vim_enter()
	elseif e == "VimLeave" then
		on_vim_quit()
	end
end

return M
