local orgmode_config = require("orgmode.config")
local jupyter_api = require("jupyter-api")
local utils = require("org-notebook.utils")
local serpent = require("org-notebook.serpent")

local M = {}

local config = {
	media_rankings = {
		"image/svg+xml",
		"image/png",
		"image/jpeg",
		"image/gif",
		"text/x-org",
		"text/latex",
		"text/markdown",
		"application/json",
		"text/plain",
	},
	media_extensions = {
		["image/svg+xml"] = "svg",
		["image/png"] = "png",
		["image/jpeg"] = "jpeg",
		["image/gif"] = "gif",
		["text/x-org"] = "org",
		["text/latex"] = "tex",
		["text/markdown"] = "md",
		["application/json"] = "json",
		["text/plain"] = "txt",
	},
	base64_encoded_mimetypes = {
		"image/png",
		"image/jpeg",
		"image/gif",
	},
}

---@param bufnr number
---@param kernel JupyterKernelspecDir
local function init_kernel_callback(bufnr, kernel)
	---See https://orgmode.org/manual/Results-of-Evaluation.html
	---@param results_format OrgResultsHeader
	---@param results_base_dir string
	---@param extra_params table
	---@param block_name string
	---@param data JupyterMessage
	---@return string, string
	local function format_execute_result(results_format, results_base_dir, extra_params, block_name, data)
		---@param results string
		---@param mime_type string
		---@return string
		local function write_result_file(results, mime_type)
			local file_base_dir = ""
			local file_path = ""
			if extra_params[":file"] then
				if extra_params[":output-dir"] then
					if extra_params[":output-dir"]:sub(1, 1) == "/" then
						file_base_dir = "/"
					else
						file_base_dir = results_base_dir .. "/"
					end
					file_path = extra_params[":output-dir"] .. "/" .. extra_params[":file"]
				else
					file_base_dir = results_base_dir
					file_path = results_base_dir .. "/" .. extra_params[":file"]
				end
			else
				file_base_dir = results_base_dir .. "/"
				file_path = string.format(
					"%s.%s",
					block_name,
					extra_params[":file-ext"] or config.media_extensions[mime_type] or "txt"
				)
			end
			local out = io.open(file_base_dir .. file_path, "w+b")
			vim.notify(file_base_dir .. file_path)
			assert(out ~= nil)
			out:write(results)
			out:close()
			return file_path
		end

		for _, mime_type in ipairs(config.media_rankings) do
			if data.content.data[mime_type] == nil then
				goto continue
			end
			if mime_type:sub(1, #"image") == "image" then
				if results_format.format ~= "graphics" then
					goto continue
				end
				local result_contents = data.content.data[mime_type]
				for _, base64_mime_type in ipairs(config.base64_encoded_mimetypes) do
					if mime_type == base64_mime_type then
						result_contents = vim.base64.decode(result_contents)
					end
				end
				return write_result_file(result_contents, mime_type), mime_type
			else
				if results_format.type == "scalar" or results_format.type == "verbatim" then
					return data.content.data[mime_type], mime_type
				end
			end
			::continue::
		end
		utils.error("No valid mime type found from an execute result, this should never happen!")
		return "", "text/plain"
	end

	---@param results_format OrgResultsHeader
	---@param block_name string
	---@param in_output string
	---@param mime_type string | nil
	---@param file_desc string | nil
	local function write_result(results_format, block_name, in_output, mime_type, file_desc)
		local output = {}
		for line in utils.magiclines(in_output) do
			table.insert(output, line)
		end

		if results_format.format == "graphics" then
			output = { "[[file:" .. in_output .. "]]" }
		end
		if results_format.block_type ~= nil then
			table.insert(output, 1, "#+BEGIN_" .. results_format.block_type)
			table.insert(output, "#+END_" .. results_format.block_type)
		end
		if results_format.format == "code" then
			local code_type = config.media_rankings[mime_type] or "unknown"
			table.insert(output, 1, "#+BEGIN_SRC " .. code_type)
			table.insert(output, "#+END_SRC " .. code_type)
		end
		if
			(results_format.type == "scalar" or results_format.type == "verbatim")
			and results_format.format == "raw"
		then
			for idx, line in ipairs(output) do
				output[idx] = ": " .. line
			end
		end
		if results_format.format == "drawer" then
			table.insert(output, 1, ":RESULTS:")
			table.insert(output, ":END:")
		end

		local parser = vim.treesitter.get_parser(bufnr, "org")
		assert(parser ~= nil)
		local tree_root = parser:trees()[1]:root()
		local results_query = vim.treesitter.query.get("org", "results_directive")
		assert(results_query ~= nil)
		for _, captures in results_query:iter_matches(tree_root, bufnr) do
			---@type TSNode
			local results_directive_name = captures[utils.find_capture_index(results_query, "name")][1]
			---@type TSNode
			local results_directive = captures[utils.find_capture_index(results_query, "directive")][1]
			if vim.treesitter.get_node_text(results_directive_name, bufnr) == block_name then
				if results_directive:parent():type() == "body" then
					-- Insert after the directive
					local directive_end_line = results_directive:end_()
					vim.api.nvim_buf_set_lines(bufnr, directive_end_line, directive_end_line, false, output)
				else
					local paragraph_end_line = results_directive:parent():end_()
					local directive_end_line = results_directive:end_()
					vim.api.nvim_buf_set_lines(bufnr, directive_end_line, paragraph_end_line, false, output)
				end
			end
		end
	end

	---@param err any
	---@param message JupyterMessage
	local function message_read_callback(err, message)
		local buffer_name = vim.api.nvim_buf_get_name(bufnr)
		local buffer_result_dir = ""
		if buffer_name == "" then
			local output_temp_dir = vim.fn.tempname()
			vim.fn.mkdir(output_temp_dir, "p")
			buffer_result_dir = output_temp_dir
			vim.api.nvim_create_autocmd({ "BufUnload" }, {
				buffer = bufnr,
				callback = function()
					vim.fn.system({ "rm", "-Rf", output_temp_dir })
				end,
			})
		else
			-- From https://stackoverflow.com/a/12191225
			buffer_result_dir = string.match(buffer_name, "(.-)([^\\/]-%.?([^%.\\/]*))$")
		end

		if err then
			utils.error(err)
			return
		end

		if message.parent_header.msg_id then
			if message.parent_header.msg_type == "execute_request" then
				local parent_message_state =
					vim.b[bufnr].kernel_connections[kernel.kernel_name]["message_" .. message.parent_header.msg_id]
				local results_format = utils.parse_org_results_header(
					parent_message_state.extra_params[":results"] or "",
					parent_message_state.extra_params[":wrap"] or nil
				)
				if message.header.msg_type == "error" then
					local joined_traceback = ""
					for idx, trace in ipairs(message.content.traceback) do
						joined_traceback = joined_traceback .. trace
						if idx ~= #message.content.traceback then
							joined_traceback = joined_traceback .. "\n"
						end
					end
					utils.error("The %s kernel produced an error!\n%s", kernel.kernel_name, joined_traceback)
				end
				if results_format.collection == "value" then
					if message.header.msg_type == "execute_result" then
						local formatted_execute_result, mime_type = format_execute_result(
							results_format,
							buffer_result_dir,
							parent_message_state.extra_params,
							parent_message_state.block_name,
							message
						)
						write_result(
							results_format,
							parent_message_state.block_name,
							formatted_execute_result,
							mime_type,
							parent_message_state.extra_params[":file-desc"] or nil
						)
					end
				elseif results_format.collection == "output" then
					if message.header.msg_type == "stream" then
						vim.b[bufnr].kernel_connections =
							vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
								[kernel.kernel_name] = {
									["message_" .. message.parent_header.msg_id] = {
										out_stream_content = vim.b[bufnr].kernel_connections[kernel.kernel_name]["message_" .. message.parent_header.msg_id].out_stream_content
											.. message.content.text,
									},
								},
							})
						write_result(
							results_format,
							parent_message_state.block_name,
							vim.b[bufnr].kernel_connections[kernel.kernel_name]["message_" .. message.parent_header.msg_id].out_stream_content,
							nil,
							nil
						)
					end
				else
					utils.error(
						"Found an invalid collection type, this should never happen! %s",
						results_format.collection
					)
				end
			end
		end
	end

	vim.b[bufnr].kernel_connections = vim.tbl_extend("force", vim.b[bufnr].kernel_connections, {
		[kernel.kernel_name] = {
			status = "STARTING",
			specdir = kernel,
		},
	})
	local ports = {}
	for _ = 1, 5 do
		table.insert(ports, utils.peek_port())
	end
	---@type JupyterConnectionInfo
	local kernel_conn_info = {
		kernel_name = kernel.kernel_name,
		-- Because IPv4 is bad
		ip = "::1",
		transport = "tcp",
		shell_port = ports[1],
		iopub_port = ports[2],
		stdin_port = ports[3],
		control_port = ports[4],
		hb_port = ports[5],
		key = utils.hmac_key(),
		signature_scheme = "hmac-sha256",
	}
	local kernel_conn_info_file_path = vim.fn.tempname()
	local kernel_conn_info_file = io.open(kernel_conn_info_file_path, "w")
	assert(kernel_conn_info_file ~= nil)
	kernel_conn_info_file:write(vim.json.encode(kernel_conn_info))
	kernel_conn_info_file:close()
	vim.b[bufnr].kernel_connections = vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
		[kernel.kernel_name] = {
			conn_info = kernel_conn_info,
			conn_info_file = kernel_conn_info_file_path,
		},
	})
	local kernel_command, kernel_args = utils.cmd_rest(unpack(kernel.kernelspec.argv))
	kernel_args = utils.map(kernel_args, function(arg)
		if arg == "{connection_file}" then
			return kernel_conn_info_file_path
		else
			return arg
		end
	end)
	---@diagnostic disable-next-line: missing-fields
	local kernel_proc = vim.uv.spawn(kernel_command, {
		stdio = { nil, nil, nil },
		args = kernel_args,
		env = kernel.kernelspec.env,
		detached = false,
	}, function(code, signal)
		vim.schedule(function()
			vim.b[bufnr].kernel_connections = vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
				[kernel.kernel_name] = {
					status = "EXITED",
					exit_code = code,
					exit_signal = signal,
				},
			})
		end)
	end)
	assert(kernel_proc ~= nil)
	vim.api.nvim_create_autocmd({ "BufUnload" }, {
		buffer = bufnr,
		callback = function()
			kernel_proc:kill("sigterm")
		end,
	})
	vim.b[bufnr].kernel_connections = vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
		[kernel.kernel_name] = {
			status = "RUNNING",
			pid = kernel_proc:get_pid(),
		},
	})
	jupyter_api.connect(kernel_conn_info, function(conn, set_read_callback, send)
		vim.schedule(function()
			vim.b[bufnr].kernel_connections = vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
				[kernel.kernel_name] = {
					session_id = conn.session_id,
					send = send,
				},
			})
			set_read_callback(vim.schedule_wrap(message_read_callback))
		end)
	end)
end

local commands = {
	---@param bufnr integer
	---@param opts { kernel_name: string | nil }
	init_kernel = function(bufnr, opts)
		jupyter_api.list_kernels(function(kernels)
			if not opts.kernel_name then
				vim.ui.select(
					kernels,
					{
						---@param item JupyterKernelspecDir
						---@return string
						format_item = function(item)
							return item.kernel_name
						end,
					},
					vim.schedule_wrap(function(kernel)
						init_kernel_callback(bufnr, kernel)
					end)
				)
			else
				init_kernel_callback(
					bufnr,
					utils.first_in_list_matching(kernels, function(kernel)
						return kernel.kernel_name == opts.kernel_name
					end)
				)
			end
		end)
	end,

	run_cell = function(bufnr)
		local parser = vim.treesitter.get_parser(bufnr, "org")
		assert(parser ~= nil)
		local tree_root = parser:trees()[1]:root()
		local cell_query = vim.treesitter.query.get("org", "notebook_cell")
		assert(cell_query ~= nil)
		local cursor_pos = vim.api.nvim_win_get_cursor(0)
		cursor_pos = { cursor_pos[1] - 1, cursor_pos[2] }
		for _, captures in cell_query:iter_matches(tree_root, bufnr) do
			local language = orgmode_config:detect_filetype(
				vim.treesitter.get_node_text(captures[utils.find_capture_index(cell_query, "language")][1], bufnr),
				true
			)
			local block_name =
				vim.treesitter.get_node_text(captures[utils.find_capture_index(cell_query, "name")][1], bufnr)
			local extra_params = ""
			for idx, value in ipairs(captures[utils.find_capture_index(cell_query, "extra_params")]) do
				if idx == 1 then
					extra_params = vim.treesitter.get_node_text(value, bufnr)
				else
					extra_params = extra_params .. " " .. vim.treesitter.get_node_text(value, bufnr)
				end
			end
			local code = vim.treesitter.get_node_text(captures[utils.find_capture_index(cell_query, "code")][1], bufnr)
			---@type TSNode
			local block = captures[utils.find_capture_index(cell_query, "block")][1]
			if vim.treesitter.is_in_node_range(block, cursor_pos[1], cursor_pos[2]) then
				local kernel_name = utils.get_kernel_name_for_language(bufnr, language)
				local msg_id = utils.uuidv4()
				vim.b[bufnr].kernel_connections[kernel_name].send({
					header = {
						msg_id = msg_id,
						username = "org-notebook",
						session = vim.b[bufnr].kernel_connections[kernel_name].session_id,
						date = utils.jupyter_timestamp(),
						msg_type = "execute_request",
						version = "5.3",
					},
					parent_header = vim.NIL,
					metadata = vim.empty_dict(),
					content = {
						code = code,
						silent = false,
						store_history = true,
						user_expressions = vim.empty_dict(),
						allow_stdin = false,
						stop_on_error = true,
					},
					channel = "shell",
				})
				vim.b[bufnr].kernel_connections = vim.tbl_deep_extend("force", vim.b[bufnr].kernel_connections, {
					[kernel_name] = {
						["message_" .. msg_id] = {
							block_name = block_name,
							extra_params = orgmode_config:parse_header_args(extra_params),
							-- Used for "output" cells
							out_stream_content = "",
						},
					},
				})
			end
		end
	end,
}

M.setup = function(user_config)
	config = vim.tbl_deep_extend("force", config, user_config or {})
	if user_config.media_rankings then
		config.media_rankings = user_config.media_rankings
	end
end

M.org_init = function(bufnr)
	vim.b[bufnr].kernel_connections = vim.empty_dict()
	vim.api.nvim_buf_create_user_command(bufnr, "OrgNotebook", function(cmd_args)
		-- Adapted from fzf-lua: https://github.com/ibhagwan/fzf-lua/blob/cae96b0/lua/fzf-lua/cmd.lua#L11
		local cmd, args = utils.cmd_rest(unpack(cmd_args.fargs))

		if not commands[cmd] then
			utils.error("invalid command '%s'", cmd)
			return
		end

		local opts = {}

		for _, arg in ipairs(args) do
			local key = arg:match("^[^=]+")
			local val = arg:match("=") and arg:match("=(.*)$")
			if val and #val > 0 then
				local ok, loaded = serpent.load(val)
				-- Parsed string wasn't "nil"  but loaded as `nil`, use as is
				if val ~= "nil" and loaded == nil then
					ok = false
				end
				if ok and (type(loaded) ~= "table" or not utils.tbl_isempty(loaded)) then
					opts[key] = loaded
				else
					opts[key] = val
				end
			end
		end

		commands[cmd](bufnr, opts)
	end, {
		nargs = "*",
		complete = function() end,
	})

	-- Automatically start any kernels the file directives want
	pcall(vim.treesitter.start, bufnr, "org")
	vim.fn.timer_start(200, function()
		local parser = vim.treesitter.get_parser(bufnr, "org")
		assert(parser ~= nil)
		local tree_root = parser:trees()[1]:root()
		local notebook_directive_query = vim.treesitter.query.get("org", "notebook_directive")
		assert(notebook_directive_query ~= nil)
		for _, captures in notebook_directive_query:iter_matches(tree_root, bufnr) do
			local directive_type = vim.treesitter.get_node_text(
				captures[utils.find_capture_index(notebook_directive_query, "directive_type")][1],
				bufnr
			)
			local directive_value = vim.treesitter.get_node_text(
				captures[utils.find_capture_index(notebook_directive_query, "directive_value")][1],
				bufnr
			)
			if string.lower(directive_type) == "org_notebook_kernel" then
				commands.init_kernel(bufnr, {
					kernel_name = directive_value,
				})
			end
		end
	end)
end

return M
