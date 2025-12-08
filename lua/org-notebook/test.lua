require("mini.test").run({
	collect = {
		emulate_busted = true,
		find_files = function()
			return vim.fn.globpath("tests/org-notebook", "**/test_*.lua", true, true)
		end,
	},
})
