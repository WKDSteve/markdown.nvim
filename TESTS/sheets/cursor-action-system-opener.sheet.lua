-- `ma` on an https link hands the URL to the system opener chain of `markdown.util.platform` (rundll32 on Windows,
-- `vim.ui.open` -> xdg-open / open elsewhere), which starts a real process. The openers are recording stand-ins
-- (`fakes`): the sheet proves which program got which URL, not that a browser tab came up.
-- On Windows the chain names `rundll32.exe`; a `.cmd` stand-in only catches the bare name, so a `lua` step strips the
-- `.exe` before the real `platform._spawn` runs (testing.nvim task fakes-unter-windows-exe-namen-explorer-exe-rundll32-exe-und).
return {
  id = "handler.cursor-action-system-opener",
  feature = "markdown.cursor-action",
  title = "markdown.nvim: ma on an https link starts the system opener with that URL",
  engine = "rpc",
  sizes = { { rows = 10, cols = 100 } },
  fakes = { "rundll32", "xdg-open", "open" },
  steps = {
    { lua = 'vim.opt.shortmess:append("I")' },
    { lua = 'require("markdown").setup({})', note = "the real setup (keymap ma)" },
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
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Read the [Docs](https://example.test/docs) first." })
      vim.bo.filetype = "markdown"
      vim.api.nvim_win_set_cursor(0, { 1, (vim.api.nvim_get_current_line():find("[Docs]", 1, true)) + 1 })]],
      note = "a line with an https link, cursor on it",
    },
    { keys = "ma", note = "ma" },
    {
      wait = [[(function()
        local fp = require("testing.fake_programs")
        local n = 0
        for _, p in ipairs({ "rundll32", "xdg-open", "open" }) do n = n + #fp.read(vim.env.TESTING_FAKES, p) end
        return n == 1
      end)()]],
      note = "one opener was started",
    },
    {
      expect = [[(function()
        local fp = require("testing.fake_programs")
        for _, p in ipairs({ "rundll32", "xdg-open", "open" }) do
          local calls = fp.read(vim.env.TESTING_FAKES, p)
          if #calls == 1 then
            local argv = calls[1].argv
            if argv[#argv] ~= "https://example.test/docs" then error(p .. " got " .. vim.inspect(argv), 0) end
            return true
          end
        end
        return false
      end)()]],
      note = "the opener got the URL under the cursor",
    },
  },
  manual = {
    "Once in the real editor: ma on an https link opens the page in the default browser",
  },
}
