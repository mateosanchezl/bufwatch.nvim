local M = {}

local state = {
	projects = {},
	current_root = "",
	current_file_path = "",
}

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

local function register_project_root()
	local cwd = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:h")
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
		state.current_root = ""
		return nil
	end

	if state.current_root ~= git_root then
		state.current_root = git_root
	end

	if not state.projects[git_root] then
		state.projects[git_root] = {
			files = {},
			metadata = {},
		}
	end

	return git_root
end

local function register_current_file()
	if state.current_root == "" then
		return nil
	end

	local file_path = vim.api.nvim_buf_get_name(0)
	state.current_file_path = file_path

	local curr_project = state.projects[state.current_root]
	if not curr_project then
		return nil
	end

	local file_data = curr_project.files[file_path]
	if not file_data then
		file_data = {
			total_time_s = 0,
			last_start = nil,
		}
		curr_project.files[file_path] = file_data
	end

	return file_data
end

local function register_buffer()
	if not register_project_root() then
		return nil
	end

	return register_current_file()
end

local function start_local_time_for_buf(file_data)
	if not file_data then
		return
	end

	file_data.last_start = os.time()
end

-- Calculates and saves total elapsed time in-memory
local function sync_elapsed_time()
	if state.current_root == "" or state.current_file_path == "" then
		return
	end

	local project = state.projects[state.current_root]
	if not project then
		return
	end

	local file_data = project.files[state.current_file_path]
	if not file_data or not file_data.last_start then
		return
	end

	local elapsed = os.time() - file_data.last_start
	print("Last elapsed: ", elapsed)
	if elapsed > 0 then
		local prev = file_data.total_time_s
		file_data.total_time_s = file_data.total_time_s + elapsed
		print("Updated total time from ", prev, " to ", file_data.total_time_s + elapsed)
	end
	file_data.last_start = nil
end

local function on_buf_enter()
	if not is_real_file(0) then
		print("Buffer not detected as real, skipping: ", vim.api.nvim_buf_get_name(0))
		return
	end

	local file_data = register_buffer()
	if not file_data then
		return
	end

	start_local_time_for_buf(file_data)
end

local function on_buf_leave()
	if state.current_root == "" or state.current_file_path == "" then
		return
	end

	sync_elapsed_time()
	state.current_file_path = ""
end

function M.on_event(event)
	local e = event.event
	if e == "BufEnter" or e == "FocusGained" then
		on_buf_enter()
	elseif e == "BufLeave" or e == "FocusLost" then
		on_buf_leave()
	end
end

return M
