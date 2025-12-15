local group = vim.api.nvim_create_augroup("bufwatch", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufLeave", "FocusGained", "FocusLost" }, {
	group = group,
	callback = function(event)
		require("bufwatch").on_event(event)
	end,
})
