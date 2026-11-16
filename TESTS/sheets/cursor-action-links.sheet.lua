-- Live check: `ma` and a double-click open the link under the cursor
-- (task markdown.nvim/ma-und-doppelklick-nehmen-die-erste-klammer-der-zeile-statt).
-- Automated: in the real editor with the real setup (keymaps included) a line with a plain
-- parenthesis that names a file, `(TCShell.exe ...)`, followed by two https links: `ma` on the
-- second link and a double-click on the first hand exactly that URL to the system opener, and no
-- "External anchor" warning appears. The system opener itself is a recording stand-in (a `lua`
-- step replaces `markdown.util.platform.open`): which browser comes up is left for a person.
return {
  id = "handler.cursor-action-links",
  feature = "markdown.cursor-action",
  title = "markdown.nvim: ma and double-click open the link under the cursor",
  task = "markdown.nvim/ma-und-doppelklick-nehmen-die-erste-klammer-der-zeile-statt",
  engine = "rpc",
  sizes = { { rows = 10, cols = 120 } },
  steps = {
    { lua = 'vim.opt.shortmess:append("I")' },
    {
      lua = 'require("markdown").setup({})',
      note = "the real setup (keymaps ma and <2-LeftMouse>)",
    },
    {
      lua = [[_G.opened = {}
      local platform = require("markdown.util.platform")
      platform.open = function(target)
        _G.opened[#_G.opened + 1] = target
        return true
      end]],
      note = "the system opener records instead of starting a browser",
    },
    {
      lua = [[vim.o.swapfile = false
      vim.o.mouse = "a"
      vim.wo.wrap = false
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Start (TCShell.exe in your Tosca Commander folder, see Tricentis/Tosca Testsuite) then [Guide](https://example.test/guide) or [Docs](https://example.test/docs).",
      })
      vim.bo.filetype = "markdown"
      vim.cmd("messages clear")]],
      note = "a line with a file-like parenthesis before two https links",
    },
    {
      lua = [[vim.api.nvim_win_set_cursor(0, { 1, (vim.api.nvim_get_current_line():find("[Docs]", 1, true)) + 1 })]],
      note = "cursor on the second link",
    },
    { keys = "ma", note = "ma" },
    { wait = "#_G.opened == 1", note = "one target handed over" },
    {
      expect = "_G.opened[1] == 'https://example.test/docs'",
      note = "the link under the cursor, not TCShell.exe",
    },
    {
      -- the screen cell of the link text, taken after the cursor is back at the line start (the
      -- line is wider than the window: `ma` on the second link scrolled it sideways)
      lua = [[vim.api.nvim_win_set_cursor(0, { 1, 0 })
      vim.cmd("redraw")
      local col = vim.api.nvim_get_current_line():find("[Guide]", 1, true) + 2
      local pos = vim.fn.screenpos(0, 1, col)
      for _ = 1, 2 do
        vim.api.nvim_input_mouse("left", "press", "", 0, pos.row - 1, pos.col - 1)
        vim.api.nvim_input_mouse("left", "release", "", 0, pos.row - 1, pos.col - 1)
      end]],
      note = "double-click on the first link",
    },
    { wait = "#_G.opened == 2", note = "a second target handed over" },
    { expect = "_G.opened[2] == 'https://example.test/guide'", note = "the double-clicked link" },
    {
      expect = "not vim.fn.execute('messages'):find('External anchor', 1, true)",
      note = "no External anchor warning",
    },
  },
  manual = {
    "Once in the real editor: ma on such a line opens the page in the browser",
  },
}
