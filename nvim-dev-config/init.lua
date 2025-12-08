vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldcolumn = "0"
vim.opt.foldtext = ""
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldnestmax = 4

require("catppuccin").setup({
	flavour = "mocha",
	float = {
		transparent = true,
		solid = true,
	},
	transparent_background = true,
})
vim.cmd.colorscheme("catppuccin")
require("nvim-treesitter.configs").setup({
	highlight = { enable = true },
})
require("orgmode").setup({
	org_startup_folded = "inherit",
	org_todo_keywords = { "TODO", "STARTED", "|", "DONE", "CANCELED" },
})
