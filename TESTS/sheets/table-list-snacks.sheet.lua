-- Live check: `:Markdown table list` in the real snacks picker
-- (task markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu, point "snacks").
-- Automated: pickers.nvim with the snacks engine opens the list of the tables of the buffer, the preview
-- starts on the file around the table ("normal"), `<M-c>` switches it to the table alone and back, and
-- choosing the second entry jumps to the second table. n/a without snacks.nvim or pickers.nvim (neither is
-- a dependency of markdown.nvim). Left for a person: whether the preview reads well. The fzf-lua engine
-- has its own terminal spec (TESTS/pty_table_list_spec.lua).
local P = 'dofile(vim.fn.getcwd() .. "/TESTS/support/plugins.lua")'
return {
  id = "table.list-snacks",
  title = "markdown.nvim: :Markdown table list in the snacks picker",
  task = "markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu",
  engine = "rpc",
  sizes = { { rows = 36, cols = 100 } },
  requires = {
    {
      lua = P .. '.have({ "snacks.nvim", "pickers.nvim" })',
      reason = "snacks.nvim or pickers.nvim is not installed here",
    },
  },
  steps = {
    {
      lua = [[vim.opt.shortmess:append("I"); vim.o.laststatus = 0; vim.o.ruler = false
      local P = dofile(vim.fn.getcwd() .. "/TESTS/support/plugins.lua")
      P.use({ "snacks.nvim", "pickers.nvim" })
      local root = vim.fs.normalize(vim.fn.tempname())
      vim.fn.mkdir(root, "p")
      vim.fn.writefile({
        "# Doc", "", "| Name | Note |", "| --- | --- |", "| a | first |", "| b | second |", "",
        "text", "", "| X | Y |", "| - | - |", "| 1 | 2 |", "", "tail",
      }, root .. "/doc.md")
      vim.cmd.cd(vim.fn.fnameescape(root))
      require("markdown").setup({})
      require("snacks").setup({ picker = { enabled = true } })
      require("pickers").setup({ engine = "snacks" })
      vim.cmd.edit("doc.md")]],
      note = "doc.md with two tables (lines 3 and 10); markdown.nvim, snacks.nvim and pickers.nvim set up",
    },
    { lua = [[vim.cmd("Markdown table list")]], note = "open the list of tables" },
    {
      wait = [[vim.bo.filetype == "snacks_picker_input"]],
      timeout = 5000,
      note = "the snacks picker is open",
    },
    {
      wait = [[(function()
        for _, w in ipairs(vim.api.nvim_list_wins()) do
          if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_picker_list" then
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)
            local text = table.concat(lines, "\n")
            return text:find("doc.md:3", 1, true) ~= nil and text:find("doc.md:10", 1, true) ~= nil
          end
        end
        return false
      end)()]],
      timeout = 5000,
      note = "both tables are listed, with their line and header",
    },
    { wait = [[vim.wait(300, function() return false end) or true]], note = "let the picker draw" },
    {
      screen = "list-normal",
      masks = { { row = 36 } },
      cursor = false,
      mode = false,
      note = "the list with the preview of the file around the table",
    },
    { input = "<M-c>", note = "switch the preview to the table alone" },
    { wait = [[vim.wait(500, function() return false end) or true]], note = "let the picker draw" },
    {
      screen = "list-table",
      masks = { { row = 36 } },
      cursor = false,
      mode = false,
      note = "the preview shows the formatted table",
    },
    { input = "<M-c>", note = "and back" },
    { wait = [[vim.wait(300, function() return false end) or true]], note = "let the picker draw" },
    { input = "<Down>", note = "second entry" },
    { wait = [[vim.wait(300, function() return false end) or true]], note = "let the picker draw" },
    { input = "<CR>", note = "choose it" },
    {
      wait = [[vim.bo.filetype == "markdown" and vim.api.nvim_win_get_cursor(0)[1] == 10]],
      timeout = 5000,
      note = "the picker closed and the cursor is on the second table (line 10)",
    },
  },
  judge = {
    "The preview of the file around the table and the table alone both read well",
  },
  manual = {},
}
