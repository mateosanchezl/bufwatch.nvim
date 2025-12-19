local state = require("bufwatch.state")

local M = {}

function M.start(file_data)
	if not file_data then
		return
	end

	file_data.last_start = os.time()
end

-- Calculates and saves total elapsed time in-memory
function M.sync_elapsed_time()
	local current_root = state.get_current_root()
	local current_file_path = state.get_current_file_path()

	if current_root == "" or current_file_path == "" then
		return
	end

	local project = state.get_project(current_root)
	if not project then
		return
	end

	local file_data = project.files[current_file_path]
	if not file_data or not file_data.last_start then
		return
	end

	local elapsed = os.time() - file_data.last_start
	if elapsed > 0 then
		file_data.total_time_s = file_data.total_time_s + elapsed
	end
	file_data.last_start = nil
end

return M
