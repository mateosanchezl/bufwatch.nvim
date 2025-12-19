local state = require("bufwatch.state")

local M = {}

local function detect_git_root(bufnr)
	local cwd = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p:h")
	local git_root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]

	if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
		return nil
	end

	return git_root
end

function M.register_project_root(bufnr)
	local git_root = detect_git_root(bufnr)

	if not git_root then
		state.set_current_root("")
		return nil
	end

	if state.get_current_root() ~= git_root then
		state.set_current_root(git_root)
	end

	local projects = state.get_projects()
	if not projects[git_root] then
		projects[git_root] = {
			files = {},
			metadata = {},
		}
	end

	return git_root
end

function M.register_file(bufnr)
	local project_root = M.register_project_root(bufnr)
	if not project_root then
		return nil
	end

	local file_path = vim.api.nvim_buf_get_name(bufnr)
	state.set_current_file_path(file_path)

	local project = state.get_project(project_root)
	if not project then
		return nil
	end

	local file_data = project.files[file_path]
	if not file_data then
		file_data = {
			total_time_s = 0,
			last_start = nil,
		}
		project.files[file_path] = file_data
	end

	return file_data
end

return M
