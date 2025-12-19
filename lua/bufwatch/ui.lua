local state = require("bufwatch.state")

local M = {}

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

local function format_time(seconds)
	seconds = math.floor(seconds)

	if seconds < 60 then
		return string.format("%ds", seconds)
	end

	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60

	if minutes < 60 then
		return string.format("%dm %02ds", minutes, seconds)
	end

	local hours = math.floor(minutes / 60)
	minutes = minutes % 60

	return string.format("%dh %02dm", hours, minutes)
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
	table.insert(out, "BufWatch - Time Spent")
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
			local formatted_time = format_time(tonumber(file.time))
			table.insert(out, string.format("  %-35s %8s", rel, formatted_time))
		end

		table.insert(out, "")
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

	state.load()

	local raw = table_to_lines(state.get_projects())
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

return M
