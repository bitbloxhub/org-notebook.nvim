local mini_test = require("mini.test")

describe("plot example", function()
	local child = mini_test.new_child_neovim()

	before_each(function()
		child.restart({ "-u", "nvim-dev-config/init.lua" }, {
			nvim_executable = nixCats.packageBinPath,
		})
	end)

	it("produces the right plot", function()
		child.cmd("edit tests/org-notebook/plot_example.org")
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
		-- Can't use the hash because of floating point precision being weird
		mini_test.expect.equality(string.sub(vim.fn.readblob("tests/org-notebook/plot_example.svg"), 1, #"<svg"), "<svg")
	end)
end)
