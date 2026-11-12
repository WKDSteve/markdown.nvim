-- Live check: `:Markdown table list` in the snacks and fzf-lua pickers
-- (task markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu, point "snacks und fzf-lua").
-- The list, the two preview modes (`<M-c>`) and the jump are automated for both engines:
--   snacks:  TESTS/sheets/table-list-snacks.sheet.lua  (the real picker in a child editor)
--   fzf-lua: TESTS/pty_table_list_spec.lua             (the real fzf window in tmux, WSL on Windows)
-- The backend choice and the preview modes are also covered headless by TESTS/table_list_spec.lua.
-- Neither engine is a dependency of markdown.nvim, so CI reports both as n/a. What stays here is what only
-- your own setup shows.
return {
  id = "table.list-pickers",
  feature = "markdown.table-list",
  title = "markdown.nvim: :Markdown table list in your own picker setup",
  task = "markdown.nvim/live-tests-im-echten-editor-snacks-fzf-lua-folds-insert-modu",
  engine = "manual",
  manual = {
    "in your real config (your pickers.nvim engine and layout settings, not the minimal setup of the checks) :Markdown table list opens the list with the preview, and choosing an entry jumps to the table",
  },
}
