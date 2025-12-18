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
	if elapsed > 0 then
		file_data.total_time_s = file_data.total_time_s + elapsed
	end
	file_data.last_start = nil
end

local function loadState()
	local path = vim.fn.stdpath("data") .. "/bufwatch/state.json"
	if vim.fn.filereadable(path) == 1 then
		local data = table.concat(vim.fn.readfile(path))
		state.projects = vim.json.decode(data)
	end
end

local function on_buf_enter()
	if not is_real_file(0) then
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

local function persistState()
	local dir = vim.fn.stdpath("data") .. "/bufwatch"
	local path = dir .. "/state.json"
	vim.fn.mkdir(dir, "p")
	vim.fn.writefile({ vim.json.encode(state.projects) }, path)
end

local function on_vim_quit()
	sync_elapsed_time()
	persistState()
end

local function on_vim_enter()
	if next(state.projects) == nil then
		loadState()
	end
end

local function format_stats_for_buffer(raw_lines)
	local projects = {}

	for _, line in ipairs(raw_lines) do
		local path, time = line:match("(.+)%.total_time_s%s*=%s*(%d+)")
		if path and time then
			local project_root, file_path = path:match("(.+)%.files%.(.+)")
			if project_root and file_path then
				projects[project_root] = projects[project_root] or {}
				table.insert(projects[project_root], {
					path = file_path,
					time = tonumber(time),
				})
			end
		end
	end

	local out = {}
	table.insert(out, "BufWatch - Stats")
	table.insert(out, string.rep("─", 40))
	table.insert(out, "")

	for project, files in pairs(projects) do
		local project_name = project:match("([^/]+)$") or project

		table.insert(out, project_name)
		table.insert(out, string.rep("─", #project_name))

		table.sort(files, function(a, b)
			return a.time > b.time
		end)

		for _, file in ipairs(files) do
			local rel = file.path:gsub("^.*/", "")
			table.insert(out, string.format("  %-35s %6ds", rel, file.time))
		end

		table.insert(out, "")
	end

	return out
end

local function table_to_lines(tbl, prefix, out)
	prefix = prefix or ""
	out = out or {}

	for k, v in pairs(tbl) do
		local key = prefix .. tostring(k)

		if type(v) == "table" then
			table_to_lines(v, key .. ".", out)
		else
			table.insert(out, key .. " = " .. tostring(v))
		end
	end

	return out
end

function M.open_stats_window()
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
	})

	loadState()

	local raw = table_to_lines(state.projects)
	local lines = format_stats_for_buffer(raw)

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true })

	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
end

vim.api.nvim_create_user_command("BufWatchStats", function()
	require("bufwatch").open_stats_window()
end, {})

function M.on_event(event)
	local e = event.event
	if e == "BufEnter" or e == "FocusGained" then
		on_buf_enter()
	elseif e == "BufLeave" or e == "FocusLost" then
		on_buf_leave()
	elseif e == "VimEnter" then
		on_vim_enter()
	elseif e == "VimLeave" then
		on_vim_quit()
	end
end

require("bufwatch.autocmds")

return M
