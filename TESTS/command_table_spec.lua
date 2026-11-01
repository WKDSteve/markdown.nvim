-- TESTS/command_table_spec.lua — `:Markdown` subcommands live in ONE table
-- (run, completion module, nesting, feature gate). Before, three parallel
-- tables plus a copy of the gate in bindings/usrcmds.lua had to be edited in
-- step, and a missing entry once broke `format`.

return function(H)
  local eq, ok = H.eq, H.ok
  local commands = require("markdown.commands")
  local cfg = require("markdown.config")

  -- Gate: `table` follows either feature, `gaps` follows `toc` -------------------
  cfg.setup({ features = { just_enable = { "tableview" } } })
  ok(commands.enabled("table"), "table is on with just tableview")
  ok(not commands.enabled("gaps"), "gaps is off without toc")
  ok(not commands.enabled("links"), "an unrelated subcommand is off")

  cfg.setup({ features = { just_enable = { "toc" } } })
  ok(commands.enabled("gaps"), "gaps follows the toc feature")
  ok(commands.enabled("toc"), "toc is on")
  ok(not commands.enabled("table"), "table is off without table/tableview")

  -- Every nested-completion subcommand completes its first slot ------------------------
  cfg.setup({})
  for _, name in ipairs({ "links", "refs", "table", "list", "headings", "format" }) do
    local got = commands.complete("", "Markdown " .. name .. " ")
    ok(type(got) == "table", name .. ": completion delegates and returns a list")
  end
  eq(#commands.complete("", "Markdown toc "), 0, "toc has no completion past its name")

  -- No second copy of the tables or the gate ---------------------------------------------
  local root = vim.fs.root(debug.getinfo(1, "S").source:sub(2), "lua") or "."
  local init = table.concat(vim.fn.readfile(root .. "/lua/markdown/commands/init.lua"), "\n")
  local usr = table.concat(vim.fn.readfile(root .. "/lua/markdown/bindings/usrcmds.lua"), "\n")
  ok(not init:find("sub_complete", 1, true), "no parallel completion table in commands/init.lua")
  ok(
    not init:find("SUBCOMMAND_FEATURES", 1, true),
    "no parallel feature table in commands/init.lua"
  )
  ok(not usr:find('name == "gaps"', 1, true), "usrcmds.lua does not carry its own copy of the gate")
end
