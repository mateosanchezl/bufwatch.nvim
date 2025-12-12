local M = {}

local state = {
	current_project = {
		root = nil,
		current_file = nil,
		start_time = nil,
	},
}

local function set_project_root()
	if state.current_project.root ~= nil then
		local cwd = vim.fn.fnamemodify(vim.fn.expand("%"), ":p:h")
		local git_root = vim.fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
		if vim.v.shell_error ~= 0 or not git_root then
			return
		end
		state.current_project.root = git_root
	else
		return
	end
end

local function resolve_current_file()
	state.current_project.current_file = vim.api.nvim_buf_get_name(0)
end

function M.on_buf_enter()
	set_project_root()
	resolve_current_file()

	if state.current_project.current_file == nil or state.current_project.root == nil then
		return
	end

	state.current_project.start_time = os.time()
	print("Started timer")
end

function M.on_buf_unfocus() end

function M.on_buf_refocus() end

function M.on_buf_leave()
	local elapsed = os.time() - state.current_project.start_time
	print("Time spent in " + state.current_project.current_file + ": " + elapsed + " seconds")
end

return M
