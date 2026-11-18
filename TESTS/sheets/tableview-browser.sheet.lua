-- `:Markdown table view browser` writes the table under the cursor as an HTML page and hands that file to the system
-- opener chain of `markdown.util.platform` (rundll32 on Windows, `vim.ui.open` -> xdg-open / open elsewhere). The
-- openers are recording stand-ins (`fakes`): the sheet proves the page was written and handed over, not that a browser
-- shows it. On Windows the chain names `rundll32.exe`; a `.cmd` stand-in only catches the bare name, so a `lua` step
-- strips the `.exe` before the real `platform._spawn` runs (as in cursor-action-system-opener.sheet.lua).
local OPENERS = [[{ "rundll32", "xdg-open", "open" }]]

return {
  id = "tableview.browser",
  feature = "markdown.tableview",
  title = "markdown.nvim: :Markdown table view browser opens the table as an HTML page",
  engine = "rpc",
  sizes = { { rows = 12, cols = 100 } },
  fakes = { "rundll32", "xdg-open", "open" },
  steps = {
    { lua = 'vim.opt.shortmess:append("I")' },
    { lua = 'require("markdown").setup({})', note = "the real setup (tableview commands)" },
    {
      lua = [[if vim.fn.has("win32") == 1 then
        local platform = require("markdown.util.platform")
        local spawn = platform._spawn
        platform._spawn = function(argv, on_exit)
          argv[1] = argv[1]:gsub("%.exe$", "")
          return spawn(argv, on_exit)
        end
      end]],
      note = "Windows: the bare program name, so the stand-in catches it",
    },
    {
      lua = [[vim.o.swapfile = false
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "| Name | Qty |", "| --- | --- |", "| apple | 3 |", "| pear | 12 |" })
      vim.bo.filetype = "markdown"
      vim.api.nvim_win_set_cursor(0, { 3, 2 })]],
      note = "a buffer with one pipe table, cursor in it",
    },
    { keys = ":Markdown table view browser<CR>", note = ":Markdown table view browser" },
    {
      wait = ([[(function()
        local fp = require("testing.fake_programs")
        local n = 0
        for _, p in ipairs(%s) do n = n + #fp.read(vim.env.TESTING_FAKES, p) end
        return n == 1
      end)()]]):format(OPENERS),
      note = "one opener was started",
    },
    {
      expect = ([[(function()
        local fp = require("testing.fake_programs")
        for _, p in ipairs(%s) do
          local calls = fp.read(vim.env.TESTING_FAKES, p)
          if #calls == 1 then
            local page = calls[1].argv[#calls[1].argv]
            if not page:match("tableview_[%%w_]+%%.html$") then error(p .. " got " .. page, 0) end
            local html = table.concat(vim.fn.readfile(page), "\n")
            if not (html:find("apple", 1, true) and html:find("pear", 1, true)) then error("page lacks the rows", 0) end
            return true
          end
        end
        return false
      end)()]]):format(OPENERS),
      note = "the opener got the written page, and it holds the table's rows",
    },
  },
  manual = {
    "Once in the real editor: :Markdown table view browser shows the table in the default browser",
  },
}
