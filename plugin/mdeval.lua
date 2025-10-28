-- mdeval.nvim - Evaluate code blocks in markdown and similar formats
-- Commands are created by require("mdeval").setup()
-- This file just ensures setup is called if user doesn't call it manually

if vim.g.mdeval_loaded then
	return
end

-- Auto-setup with defaults if user hasn't called setup()
vim.defer_fn(function()
	if not vim.g.mdeval_setup_called then
		require("mdeval").setup()
	end
end, 0)

vim.g.mdeval_loaded = 1
