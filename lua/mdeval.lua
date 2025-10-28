local M = {}

-- Default configuration
M.config = {
	-- Timeout in seconds (-1 for no timeout)
	timeout = -1,
	-- Label for results
	results_label = "**Results:**",
	-- Temp directory
	tmp_dir = "/tmp/mdeval",
	-- Code block delimiters by filetype
	delimiters = {
		markdown = { "```", "```" },
		["markdown.pandoc"] = { "```", "```" },
		vimwiki = { "{{{", "}}}" },
		norg = { "@code", "@end" },
		org = { "#+BEGIN_SRC", "#+END_SRC" },
	},
	-- Language configurations: lang_code -> command template
	-- Use {file} placeholder for file-based execution, otherwise stdin
	languages = {
		bash = "bash",
		sh = "bash",
		c = "gcc {file} -o {tmp}/a.out && {tmp}/a.out",
		cpp = "g++ {file} -o {tmp}/a.out && {tmp}/a.out",
		python = "python3",
		py = "python3",
		lua = "lua",
		ruby = "ruby",
		js = "node",
		rust = "rustc {file} -o {tmp}/a.out && {tmp}/a.out",
		haskell = "runghc",
	},
}

-- Get code block delimiters for current filetype
local function get_delimiters()
	local ft = vim.bo.filetype
	return M.config.delimiters[ft] or { "```", "```" }
end

-- Find code block boundaries
local function find_code_block()
	local delims = get_delimiters()
	local start_pattern = vim.pesc(delims[1]) .. ".\\+$"
	local end_pattern = vim.pesc(delims[2]) .. ".*$"

	local start_line = vim.fn.search(start_pattern, "bnW")
	local end_line = vim.fn.search(end_pattern, "nW")

	if start_line == 0 or end_line == 0 then
		return nil
	end

	return start_line, end_line
end

-- Extract language from code block start line
local function get_language(line)
	local delims = get_delimiters()
	local start_pos = line:find(delims[1], 1, true)
	if not start_pos then
		return nil
	end

	local lang = line:sub(start_pos + #delims[1]):match("^%s*(%S+)")
	return lang
end

-- Get code from buffer lines
local function get_code(start_line, end_line)
	local lines = vim.api.nvim_buf_get_lines(0, start_line, end_line - 1, false)
	return table.concat(lines, "\n")
end

-- Execute code and return output lines
local function execute(lang, code)
	local cmd_template = M.config.languages[lang]
	if not cmd_template then
		return { "Error: Unsupported language: " .. lang }
	end

	-- Create temp directory
	os.execute("mkdir -p " .. M.config.tmp_dir)

	local cmd
	if cmd_template:find("{file}") then
		-- File-based execution (for compilers)
		local ext = lang == "c" and "c"
			or lang == "cpp" and "cpp"
			or lang == "rust" and "rs"
			or lang == "haskell" and "hs"
			or "txt"
		local tmpfile = M.config.tmp_dir .. "/code." .. ext

		-- Write code to file
		local f = io.open(tmpfile, "w")
		if not f then
			return { "Error: Could not create temp file" }
		end
		f:write(code)
		f:close()

		-- Build command
		cmd = cmd_template:gsub("{file}", tmpfile):gsub("{tmp}", M.config.tmp_dir)
	else
		-- Stdin-based execution (for interpreters)
		cmd = string.format("echo %s | %s", vim.fn.shellescape(code), cmd_template)
	end

	-- Add timeout if configured
	if M.config.timeout > 0 then
		local timeout_cmd = vim.fn.executable("gtimeout") == 1 and "gtimeout" or "timeout"
		cmd = string.format("%s %d sh -c %s", timeout_cmd, M.config.timeout, vim.fn.shellescape(cmd))
	end

	-- Execute and capture output
	local handle = io.popen(cmd .. " 2>&1")
	if not handle then
		return { "Error: Failed to execute command" }
	end

	local output = {}
	for line in handle:lines() do
		table.insert(output, line)
	end
	handle:close()

	return output
end

-- Remove previous results if they exist
local function remove_previous_results(line_nr)
	local next_line = vim.fn.getline(line_nr + 1)
	if next_line ~= "" then
		return
	end

	local results_line = vim.fn.getline(line_nr + 2)
	if not results_line:find(M.config.results_label, 1, true) then
		return
	end

	-- Find end of results block
	local delims = get_delimiters()
	local end_nr = line_nr + 3 -- Start after the results label

	-- Check if there's a code block for multi-line results
	local has_code_block = vim.fn.getline(line_nr + 3):match("^%s*" .. vim.pesc(delims[1]))

	if has_code_block then
		-- Multi-line results with code block - skip opening delimiter and find closing one
		end_nr = end_nr + 1 -- Skip the opening delimiter
		while end_nr <= vim.fn.line("$") do
			local line = vim.fn.getline(end_nr)
			if line:match("^%s*" .. vim.pesc(delims[2]) .. "%s*$") then
				break
			end
			end_nr = end_nr + 1
		end
	else
		-- Single-line result (inline backticks) - just the results label line
		end_nr = line_nr + 2
	end

	-- Check if there's a trailing blank line to remove
	if vim.fn.getline(end_nr + 1) == "" then
		end_nr = end_nr + 1
	end

	vim.fn.execute(string.format("%d,%ddelete", line_nr + 1, end_nr - 1))
end

-- Write output after code block
local function write_output(line_nr, output)
	local lines = { "" }

	if #output == 0 then
		table.insert(lines, M.config.results_label .. " `<no output>`")
	elseif #output == 1 then
		table.insert(lines, M.config.results_label .. " `" .. output[1] .. "`")
	else
		table.insert(lines, M.config.results_label)
		local delims = get_delimiters()
		table.insert(lines, delims[1])
		for _, line in ipairs(output) do
			table.insert(lines, line)
		end
		table.insert(lines, delims[2])
	end

	-- Add blank line if next line isn't blank
	if vim.fn.getline(line_nr + 1) ~= "" then
		table.insert(lines, "")
	end

	for i, line in ipairs(lines) do
		vim.fn.append(line_nr + i - 1, line)
	end
end

-- Main evaluation function
function M.eval_code_block()
	local start_line, end_line = find_code_block()
	if not start_line then
		print("Not inside a code block")
		return
	end

	local first_line = vim.fn.getline(start_line)
	local lang = get_language(first_line)
	if not lang then
		print("No language specified")
		return
	end

	local code = get_code(start_line, end_line)
	if code == "" then
		print("No code found")
		return
	end

	local output = execute(lang, code)
	remove_previous_results(end_line)
	write_output(end_line, output)
end

-- Clean results
function M.clean()
	local start_line, end_line = find_code_block()
	if not start_line then
		print("Not inside a code block")
		return
	end
	remove_previous_results(end_line)
end

-- Setup function
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	-- Create commands
	vim.api.nvim_create_user_command("MdEval", function()
		M.eval_code_block()
	end, {})

	vim.api.nvim_create_user_command("MdEvalClean", function()
		M.clean()
	end, {})

	vim.g.mdeval_setup_called = true
end

return M
