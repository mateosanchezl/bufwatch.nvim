local M = {}

local state = {
	projects = {},
	current_root = "",
	current_file_path = "",
}

local function register_project_root()
	if state.current_root ~= "" then
		-- Get project root
		local cwd = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:h")
		local git_root = vim.fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
		if vim.v.shell_error ~= 0 or not git_root then
			print("Error setting project root")
			return
		end

		state.current_root = git_root
		-- Check if set
		if not state.projects[git_root] then
			state.projects[git_root] = {
				files = {},
				metadata = {},
			}
		end
	else
		-- Already set
		return
	end
end

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

local function register_current_file()
	local file_path = vim.api.nvim_buf_get_name(0)
	state.current_file_path = file_path

	local curr_project = state.projects[state.current_root]
	if not curr_project then
		error("Couldn't find this project in memory")
	end

	if not curr_project.files[file_path] then
		curr_project.files[file_path] = {
			total_time_s = 0,
			last_start = nil,
		}
	end
end

local function register_buffer()
	register_project_root()
	register_current_file()
end

local function on_buf_enter()
	if not is_real_file(0) then
		return
	end
	register_buffer()

	local s = state.current_project
	if s.current_file == "" or s.root == "" then
		error("Error getting current file or project")
		return
	end
end

-- Calculates and saves total elapsed time in-memory
local function sync_elapsed_time()
	local last_start = state.projects[state.current_root].files[state.current_file_path].last_start

	if last_start > 0 then
		local elapsed = os.time()
		print("Elapsed: ")
		state.projects[state.current_root].files[state.current_file_path].total_time_s = last_start + elapsed
		last_start = 0
	end
end

local function on_buf_leave()
	sync_elapsed_time()
end

function M.on_event(event)
	print(event)
	if event == "BufEnter" then
		on_buf_enter()
	elseif event == "BufLeave" then
		on_buf_leave()
	end
end

return M
