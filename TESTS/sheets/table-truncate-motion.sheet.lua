-- Live check: moving the cursor over cut cells (concealed text) of a truncated table
-- (task markdown.nvim/tabellen-kuerzung-und-zellen-popup-im-echten-fenster-pruefen, point 1: cursor line,
-- concealcursor, movement over hidden text, insert mode). The screen is read cell by cell with
-- `screenstring`, so the checks do not depend on a snapshot. Automated: the cursor row shows its full text,
-- the row the cursor leaves is cut again, `$` puts the screen cursor on the last visible character of the
-- full text, `w` moves along the full text, and after an insert on the row (and <Esc>) leaving the row cuts
-- it again. Left for a person: whether that feels usable.
return {
  id = "table.truncate-motion",
  feature = "markdown.table-truncate",
  title = "markdown.nvim: moving over truncated cells, and back after insert mode",
  task = "markdown.nvim/tabellen-kuerzung-und-zellen-popup-im-echten-fenster-pruefen",
  engine = "rpc",
  steps = {
    { lua = 'vim.opt.shortmess:append("I"); vim.o.laststatus = 0; vim.o.ruler = false' },
    { lua = 'require("markdown.config").setup({ table = { truncate = { max = 12 } } })' },
    {
      lua = [[vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "Text above the table.",
        "",
        "| Name | Note                                  |",
        "| ---- | ------------------------------------- |",
        "| a    | a very long note that does not fit    |",
        "| b    | another long note that does not fit   |",
        "| c    | short                                 |",
      })
      vim.bo.filetype = "markdown"
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      -- the text of the screen row where buffer line `l` starts
      _G.shown = function(l)
        local r, out = vim.fn.screenpos(0, l, 1).row, {}
        for c = 1, vim.o.columns do out[#out + 1] = vim.fn.screenstring(r, c) end
        return table.concat(out)
      end]],
      note = "a table with two over-wide rows and a short one, cursor above it",
    },
    { lua = 'require("markdown.core.table_truncate").enable(0)', note = "truncation on" },
    { wait = "vim.wo.conceallevel >= 2", note = "conceallevel raised while truncation is on" },
    {
      wait = [[_G.shown(5):find("…", 1, true) ~= nil and _G.shown(6):find("…", 1, true) ~= nil]],
      timeout = 5000,
      note = "both long rows are cut with an ellipsis",
    },
    { keys = "4j", note = "cursor onto the first long row" },
    {
      wait = [[_G.shown(5):find("does not fit", 1, true) ~= nil]],
      timeout = 5000,
      note = "the cursor row shows its full text",
    },
    {
      expect = [[_G.shown(6):find("…", 1, true) ~= nil and _G.shown(6):find("does not fit", 1, true) == nil]],
      note = "the other long row stays cut",
    },
    { keys = "$", note = "to the end of the row" },
    {
      expect = [[vim.fn.screenstring(vim.fn.screenrow(), vim.fn.screencol()) == "|"]],
      note = "the screen cursor sits on the last character of the full row (the closing bar), not on a hidden one",
    },
    { keys = "0www", note = "to the start, then three words along the full text" },
    {
      expect = [[vim.fn.screenstring(vim.fn.screenrow(), vim.fn.screencol()) == vim.api.nvim_get_current_line():sub(vim.fn.col("."), vim.fn.col("."))]],
      note = "the character under the screen cursor is the buffer character under the cursor (nothing hidden is skipped)",
    },
    { keys = "fn", note = "to the next n on the row (inside the cut text)" },
    {
      expect = [[vim.fn.screenstring(vim.fn.screenrow(), vim.fn.screencol()) == "n"]],
      note = "the screen cursor is on that n, in the full text of the cursor row",
    },
    { keys = "j", note = "leave the row downwards" },
    {
      expect = [[_G.shown(5):find("…", 1, true) ~= nil and _G.shown(5):find("does not fit", 1, true) == nil]],
      note = "the row left behind is cut again",
    },
    {
      expect = [[_G.shown(6):find("does not fit", 1, true) ~= nil]],
      note = "and the row entered shows its full text",
    },
    { input = "A", note = "insert mode at the end of the row" },
    { wait = "vim.api.nvim_get_mode().mode == 'i'" },
    {
      expect = [[_G.shown(6):find("does not fit", 1, true) ~= nil]],
      note = "in insert mode the row shows its full text",
    },
    { input = "<Esc>", note = "leave insert mode" },
    { wait = "vim.api.nvim_get_mode().mode == 'n'" },
    { keys = "k", note = "to the other row" },
    {
      wait = [[_G.shown(6):find("…", 1, true) ~= nil and _G.shown(6):find("does not fit", 1, true) == nil]],
      timeout = 5000,
      note = "the row edited in insert mode is cut again once the cursor left it",
    },
    {
      expect = [[vim.api.nvim_buf_get_lines(0, 5, 6, false)[1] == "| b    | another long note that does not fit   |"]],
      note = "the buffer text is unchanged by all of it",
    },
  },
  judge = {
    "Moving along a cut row and between rows feels usable (no jumping, the cursor never sits on hidden text)",
  },
  manual = {},
}
