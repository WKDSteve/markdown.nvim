-- TESTS/pty/init.lua -- the editor of the terminal spec (TESTS/pty_table_list_spec.lua): a real Neovim in
-- tmux (WSL on Windows) with markdown.nvim, pickers.nvim on its fzf engine and a real fzf-lua, started as
--
--   nvim --clean -c "luafile <this file>"
--
-- Everything variable comes from the environment (the spec sets it): MARKDOWN_PTY_ROOT (markdown.nvim) and
-- MARKDOWN_PTY_RTP (comma separated runtimepath entries). The project is a fresh temp directory.

local root = assert(vim.env.MARKDOWN_PTY_ROOT, "MARKDOWN_PTY_ROOT")
vim.opt.shortmess:append("I")
vim.o.laststatus = 0
vim.o.swapfile = false
vim.opt.rtp:prepend(root)
for dir in (vim.env.MARKDOWN_PTY_RTP or ""):gmatch("[^,]+") do
  vim.opt.rtp:append(dir)
end
vim.cmd("runtime! plugin/fzf-lua.lua")

local dir = vim.fn.tempname()
vim.fn.mkdir(dir, "p")
vim.fn.writefile({
  "# Doc",
  "",
  "| Name | Note |",
  "| --- | --- |",
  "| a | first |",
  "| b | second |",
  "",
  "text",
  "",
  "| X | Y |",
  "| - | - |",
  "| 1 | 2 |",
  "",
  "tail",
}, dir .. "/doc.md")
vim.cmd.cd(vim.fn.fnameescape(dir))

require("markdown").setup({})
require("pickers").setup({ engine = "fzf" })
vim.cmd.edit("doc.md")
-- the spec types only after this line is on the screen
vim.cmd("echo 'PTY-READY'")
