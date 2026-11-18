-- `DD` on a link to an existing file looks for the other notes that link there (ripgrep, off the main loop), asks
-- whether to delete the file too and, on yes, deletes the file and the line. rg runs for real on a small generated
-- project; the confirm dialog of ui.nvim is a recording stand-in that answers yes (ui.nvim is not a dependency of the
-- suite): the sheet proves the question names the other reference and that the file and the line are gone.
return {
  id = "links.delete-file",
  feature = "markdown.link-delete",
  title = "markdown.nvim: DD on a link deletes the line and, after asking, the linked file",
  engine = "rpc",
  sizes = { { rows = 16, cols = 140 } },
  steps = {
    {
      lua = [[vim.opt.shortmess:append("I")
      vim.o.swapfile = false
      vim.o.cmdheight = 3 -- "deleted <temp path>" fits without a hit-enter prompt
      require("markdown").setup({})
      _G.root = vim.fs.normalize(vim.fn.tempname())
      vim.fn.mkdir(_G.root .. "/notes", "p")
      vim.fn.writefile({ "# target" }, _G.root .. "/notes/target.md")
      vim.fn.writefile({ "# other", "", "see [T](notes/target.md)" }, _G.root .. "/other.md")
      vim.fn.writefile({ "# index", "", "[T](notes/target.md)" }, _G.root .. "/index.md")
      vim.cmd.cd(vim.fn.fnameescape(_G.root))
      _G.asked = nil
      package.loaded["ui.kit.confirm"] = {
        open = function(opts)
          _G.asked = opts.question
          opts.on_answer(true)
        end,
      }]],
      note = "three notes, two of them link to notes/target.md; the dialog answers yes",
    },
    { keys = ":edit index.md<CR>", note = "open index.md" },
    { keys = "3G", note = "the line with the link" },
    { keys = "DD", note = "DD" },
    { wait = "_G.asked ~= nil", timeout = 10000, note = "the dialog asks" },
    {
      expect = [[_G.asked:find("target.md", 1, true) ~= nil and _G.asked:find("1 other link points at it.", 1, true) ~= nil]],
      note = "it names the file and the one other note that links there",
    },
    { wait = "vim.uv.fs_stat(_G.root .. '/notes/target.md') == nil", note = "the file is deleted" },
    { expect = "#vim.api.nvim_buf_get_lines(0, 0, -1, false) == 2", note = "and the line with it" },
    { lua = [[vim.cmd("bwipeout!"); vim.cmd.cd("-"); vim.fn.delete(_G.root, "rf")]] },
  },
}
