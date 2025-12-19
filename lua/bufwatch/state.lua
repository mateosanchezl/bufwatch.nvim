local M = {
	data = {
		projects = {},
		current_root = "",
		current_file_path = "",
	},
}

function M.get_projects()
	return M.data.projects
end

function M.get_project(root)
	return M.data.projects[root]
end

function M.set_current_root(root)
	M.data.current_root = root or ""
end

function M.get_current_root()
	return M.data.current_root
end

function M.set_current_file_path(path)
	M.data.current_file_path = path or ""
end

function M.get_current_file_path()
	return M.data.current_file_path
end

function M.reset_current_file_path()
	M.data.current_file_path = ""
end

function M.load()
	local path = vim.fn.stdpath("data") .. "/bufwatch/state.json"
	if vim.fn.filereadable(path) == 1 then
		local data = table.concat(vim.fn.readfile(path))
		M.data.projects = vim.json.decode(data) or {}
	end
end

function M.persist()
	local dir = vim.fn.stdpath("data") .. "/bufwatch"
	local path = dir .. "/state.json"

	vim.fn.mkdir(dir, "p")
	vim.fn.writefile({ vim.json.encode(M.data.projects) }, path)
end

return M
