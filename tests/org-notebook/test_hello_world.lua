local mini_test = require("mini.test")

describe("hello_world_value.org", function()
	local child = mini_test.new_child_neovim()

	before_each(function()
		child.restart({ "-u", "nvim-dev-config/init.lua" }, {
			nvim_executable = nixCats.packageBinPath,
		})
	end)

	it("produces hello world", function()
		child.cmd("edit tests/org-notebook/hello_world_value.org")
		-- Remove the results
		child.api.nvim_buf_set_lines(
			0,
			child.api.nvim_buf_line_count(0) - 1,
			child.api.nvim_buf_line_count(0),
			false,
			{}
		)
		child.cmd("OrgNotebook init_kernel kernel_name=deno")
		vim.uv.sleep(2000)
		child.cmd("OrgNotebook run_cell")
		vim.uv.sleep(1000)
		mini_test.expect.reference_screenshot(child.get_screenshot())
	end)
end)

describe("hello_world_output.org", function()
	local child = mini_test.new_child_neovim()

	before_each(function()
		child.restart({ "-u", "nvim-dev-config/init.lua" }, {
			nvim_executable = nixCats.packageBinPath,
		})
	end)

	it("produces hello world", function()
		child.cmd("edit tests/org-notebook/hello_world_output.org")
		-- Remove the results
		child.api.nvim_buf_set_lines(
			0,
			child.api.nvim_buf_line_count(0) - 2,
			child.api.nvim_buf_line_count(0),
			false,
			{}
		)
		child.cmd("OrgNotebook init_kernel kernel_name=deno")
		vim.uv.sleep(2000)
		child.cmd("OrgNotebook run_cell")
		vim.uv.sleep(3000)
		mini_test.expect.reference_screenshot(child.get_screenshot())
	end)
end)
