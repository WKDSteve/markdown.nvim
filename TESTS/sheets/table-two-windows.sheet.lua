-- Live check: two windows of different width on one buffer
-- (task markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu, point "Zwei Fenster").
-- The grid extmarks belong to the buffer, not to a window, so one layout has to serve both: the table is
-- laid out for the NARROWEST window that shows the buffer (core/table_render.lua `avail`), so the right
-- border is visible in both, and when the narrow window grows the grid is laid out again for the new width.
-- Automated: the width of the drawn grid against the window widths, and the screen of both windows
-- before and after the resize. Left for a person: whether the narrow layout reads well.
return {
  id = "table.two-windows",
  feature = "markdown.table-render",
  title = "markdown.nvim: a table in two windows of different width on one buffer",
  task = "markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu",
  engine = "rpc",
  sizes = { { rows = 24, cols = 100 } },
  steps = {
    { lua = 'vim.opt.shortmess:append("I"); vim.o.laststatus = 0; vim.o.ruler = false' },
    { lua = 'require("markdown").setup({})', note = "the real setup" },
    {
      lua = [[vim.o.swapfile = false
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "# Title",
        "",
        "| Name | Note |",
        "| ---- | ---- |",
        "| alpha | a rather long cell of text that is wide |",
        "| b | short |",
        "",
        "text below the table",
      })
      vim.bo.filetype = "markdown"
      require("markdown.core.render").enable(0)
      require("markdown.core.table_render").enable(0)
      vim.cmd("vsplit")
      vim.cmd("vertical resize 70")
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      -- the widest piece the grid draws (virtual lines and virtual text), in display cells
      _G.grid_width = function()
        local ns = vim.api.nvim_create_namespace("markdown_table_render")
        local widest = 0
        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
          for _, vl in ipairs(m[4].virt_lines or {}) do
            local s = {}
            for _, chunk in ipairs(vl) do s[#s + 1] = chunk[1] end
            widest = math.max(widest, vim.fn.strdisplaywidth(table.concat(s)))
          end
          for _, chunk in ipairs(m[4].virt_text or {}) do
            widest = math.max(widest, vim.fn.strdisplaywidth(chunk[1]))
          end
        end
        return widest
      end
      -- the narrowest text area of a window showing the buffer
      _G.narrowest = function()
        local least = math.huge
        for _, win in ipairs(vim.fn.win_findbuf(vim.api.nvim_get_current_buf())) do
          local info = vim.fn.getwininfo(win)[1]
          least = math.min(least, info.width - info.textoff)
        end
        return least
      end]],
      note = "a table in a buffer shown in two windows: 70 and 29 columns wide",
    },
    {
      expect = [[vim.api.nvim_win_get_width(0) == 70 and vim.api.nvim_win_get_width(vim.fn.win_getid(2)) == 29]],
      note = "the windows have the widths the sheet assumes",
    },
    {
      wait = [[_G.grid_width() > 0]],
      timeout = 5000,
      note = "the grid is drawn",
    },
    {
      wait = [[_G.grid_width() <= _G.narrowest()]],
      timeout = 5000,
      note = "the grid is laid out for the narrow window (the layout follows the split), so its right border is visible in both",
    },
    { settle = 500 },
    { screen = "narrow-and-wide" },
    {
      lua = [[vim.cmd("wincmd l | vertical resize 55")]],
      note = "make the narrow window wider (55 columns)",
    },
    {
      wait = [[_G.grid_width() > 29]],
      timeout = 5000,
      note = "the table is laid out again for the new narrowest window",
    },
    { settle = 500 },
    {
      expect = [[_G.grid_width() <= _G.narrowest() and _G.grid_width() > 29]],
      note = "the grid grew with the window and still fits it",
    },
    { screen = "both-wide-enough" },
  },
  judge = {
    "In the narrow layout the wrapped cells read well and both windows show the same grid",
    "The wide window leaves the table narrower than it could be (by design: one layout for the buffer); acceptable",
  },
}
