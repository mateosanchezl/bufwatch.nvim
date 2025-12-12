local M = {}

local state = {
	current_project = {
		root = "",
		current_file = "",

		start_time = nil,
		total_elapsed_time = nil,
	},
}

local function set_project_root()
	if state.current_project.root ~= nil then
		local cwd = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:h")
		local git_root = vim.fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
		if vim.v.shell_error ~= 0 or not git_root then
			print("Error setting project root")
			return
		end
		state.current_project.root = git_root
	else
		-- Already set
		return
	end
end

local function resolve_current_file()
	state.current_project.current_file = vim.api.nvim_buf_get_name(0)
end

function M.on_buf_enter()
	set_project_root()
	resolve_current_file()

	if state.current_project.current_file == "" or state.current_project.root == "" then
		print("Error getting current file or project")
		return
	end

	state.current_project.start_time = os.time()
end

-- Calculates and saves total elapsed time in-state
local function sync_elapsed_time()
	local s = state.current_project

	local last_elapsed = os.time() - s.start_time
	if s.total_elapsed_time > 0 then
		s.total_elapsed_time = s.total_elapsed_time + last_elapsed
	else
		s.total_elapsed_time = last_elapsed
	end
end

function M.on_buf_unfocus()
	sync_elapsed_time()
end

function M.on_buf_refocus()
	local s = state.current_project
	s.start_time = os.time()
end

function M.on_buf_leave()
	if state.current_project.start_time == nil then
		return
	end

	sync_elapsed_time()
	-- Save to JSON or something
	-- eg:
	-- {
	--  project: "/Desktop/repo..."
	--  file_stats: {
	--    repo/init.lua: {
	--      total_elapsed_time: 15214
	--      last_reset:
	--    }
	--  }
	-- }

	-- Clear state
	state.current_project = { root = "", current_file = "", start_time = nil, total_elapsed_time = nil }
end

return M
