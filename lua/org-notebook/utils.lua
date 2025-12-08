local M = {}

---From fzf-lua: https://github.com/ibhagwan/fzf-lua/blob/cae96b04f6cad98a3ad24349731df5e56b384c3c/lua/fzf-lua/utils.lua#L141-L207
---Fancy notification wrapper, idea borrowed from blink.nvim
---@param lvl? number
---@param ... any
M.notify = function(lvl, ...)
	-- Message can be specified directly as table with highlights, i.e. { "foo", "Error" }
	-- or as a vararg of strings/numbers to be sent to string.format
	local arg1 = (...)
	local msg = type(arg1) == "table" and arg1 or string.format(...)

	local header_hl, chunks = (function()
		local hl = (function()
			if lvl == vim.log.levels.ERROR then
				return "DiagnosticVirtualLinesError"
			elseif lvl == vim.log.levels.WARN then
				return "DiagnosticVirtualLinesWarn"
			elseif lvl == vim.log.levels.INFO then
				return "DiagnosticVirtualLinesInfo"
			else
				return "DiagnosticVirtualLinesHint"
			end
		end)()
		-- When using vararg for msg (i.e. only text) we color the text based on the
		-- requested log level, when msg is already highlighted (i.e. table) we leave
		-- the msg highlights as requested by the caller and color the header (plugin
		-- name) instead
		if type(msg) == "table" then
			for i, v in ipairs(msg) do
				if type(v) ~= "table" or not v[2] then
					msg[i] = { type(v) ~= "table" and tostring(v) or v[1], "" }
				end
			end
			return hl, msg
		else
			return M._notify_header, { { msg, hl } }
		end
	end)()

	assert(type(chunks) == "table")

	table.insert(chunks, 1, { "[org-notebook.nvim]", header_hl })
	table.insert(chunks, 2, { " " })

	local function nvim_echo()
		local echo_opts = {
			verbose = false,
			err = lvl == vim.log.levels.ERROR and true or nil,
		}
		vim.api.nvim_echo(chunks, true, echo_opts)
	end
	if vim.in_fast_event() then
		vim.schedule(nvim_echo)
	else
		nvim_echo()
	end
end

M.info = function(...)
	M.notify(vim.log.levels.INFO, ...)
end

M.warn = function(...)
	M.notify(vim.log.levels.WARN, ...)
end

M.error = function(...)
	M.notify(vim.log.levels.ERROR, ...)
end

M.first_in_list_matching = function(table, matcher_fn)
	for _, value in ipairs(table) do
		if matcher_fn(value) then
			return value
		end
	end
end

M.get_kernel_name_for_language = function(bufnr, language)
	for name, kernel in pairs(vim.b[bufnr].kernel_connections) do
		if kernel.specdir.kernelspec.language == language then
			return name
		end
	end
end

---@param query vim.treesitter.Query
---@param capture_name string
---@return number?
M.find_capture_index = function(query, capture_name)
	for id, name in ipairs(query.captures) do
		if name == capture_name then
			return id
		end
	end
end

M.cmd_rest = function(cmd, ...)
	return cmd, { ... }
end

M.tbl_isempty = function(T)
	assert(type(T) == "table", string.format("Expected table, got %s", type(T)))
	return next(T) == nil
end

---Get an open port
M.peek_port = function()
	local socket = vim.uv.new_tcp()
	assert(socket ~= nil)
	socket:bind("127.0.0.1", 0)
	local result = socket:getsockname()
	socket:close()
	assert(result ~= nil)
	return result.port
end

M.hmac_key = function()
	local random_string = ""

	for _ = 1, 16 do
		local rand_byte = math.random(0, 255)
		random_string = random_string .. string.char(rand_byte)
	end

	return vim.base64.encode(random_string)
end

M.uuidv4 = function()
	return vim.fn.trim(vim.fn.system("uuidgen"))
end

---Create a time that is correctly derserialized by the rust code
---@return string
M.jupyter_timestamp = function()
	local second, microsecond = vim.uv.gettimeofday()
	local second_format = os.date("%Y-%m-%dT%H:%M:%S", second)
	local nanosecond_format = string.format("%09d", microsecond)
	local time = second_format .. "." .. nanosecond_format .. "Z"
	return time
end

M.map = function(tbl, f)
	local t = {}
	for k, v in pairs(tbl) do
		t[k] = f(v)
	end
	return t
end

M.contains = function(tbl, x)
	for _, v in pairs(tbl) do
		if v == x then
			return true
		end
	end
	return false
end

---From https://stackoverflow.com/a/19329565
---@param s string
---@return fun(): string, ...
M.magiclines = function(s)
	if s:sub(-1) ~= "\n" then
		s = s .. "\n"
	end
	return s:gmatch("(.-)\n")
end

---@alias OrgResultsHeader { collection: string, type: string, format: string, handling: string, block_type: string | nil }

---https://orgmode.org/manual/Results-of-Evaluation.html
---@param header string
---@param wrap string | nil
---@return OrgResultsHeader
M.parse_org_results_header = function(header, wrap)
	local collection_options = { "value", "output" }
	local type_options = { "table", "vector", "list", "scalar", "verbatim", "file" }
	local format_options = { "raw", "code", "drawer", "html", "latex", "link", "graphics", "org", "pp" }
	local handling_options = { "replace", "silent", "none", "discard", "append", "prepend" }
	local results = {
		collection = "value",
		type = "verbatim",
		format = "raw",
		handling = "replace",
		block_type = nil,
	}
	for part in header:gmatch("%S+") do
		if M.contains(collection_options, part) then
			results.collection = part
		end
		if M.contains(type_options, part) then
			results.type = part
		end
		if M.contains(format_options, part) then
			results.format = part
		end
		if M.contains(handling_options, part) then
			results.handling = part
		end
	end
	if wrap then
		results.block_type = wrap
	elseif results.format == "html" then
		results.block_type = "EXPORT html"
	elseif results.format == "latex" then
		results.block_type = "EXPORT latex"
	elseif results.format == "org" then
		results.block_type = "SRC org"
	end
	return results
end

return M
