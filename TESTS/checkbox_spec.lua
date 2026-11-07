---@diagnostic disable: missing-fields
-- TESTS/checkbox_spec.lua — core.checkbox, its keys, the double-click and the menu entries.
--   * The cycle `[ ]` -> `[x]` -> `[~]` -> `[ ]`, also from `[X]` and from a state outside it.
--   * Every list kind, indented, nested and quoted; CRLF and the text after the box survive.
--   * A line without a box, a link, plain brackets and a fenced example stay untouched.
--   * The cursor row counts, wherever the cursor stands; the cursor does not move.
--   * The states are configurable, a wrong list falls back to the default.
--   * The double-click only means the box when it hits the box.

return function(H)
  local eq, ok = H.eq, H.ok
  local api = vim.api
  local cb = require("markdown.core.checkbox")
  local config = require("markdown.config")

  local function line(buf, row) return api.nvim_buf_get_lines(buf, row - 1, row, false)[1] end
  local function buffer(lines)
    local buf = H.scratch("markdown")
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf
  end

  config.setup({})

  -- The cycle ---------------------------------------------------------------
  do
    local buf = buffer({ "- [ ] task" })
    api.nvim_win_set_cursor(0, { 1, 8 })
    ok(cb.cycle(), "cycle reports a step")
    eq(line(buf, 1), "- [x] task", "open -> done")
    cb.cycle()
    eq(line(buf, 1), "- [~] task", "done -> cancelled")
    cb.cycle()
    eq(line(buf, 1), "- [ ] task", "cancelled -> open")
    eq(api.nvim_win_get_cursor(0)[2], 8, "the cursor stays where it was")

    buf = buffer({ "- [X] upper", "- [-] partial" })
    cb.cycle(buf, 1)
    eq(line(buf, 1), "- [~] upper", "X counts as x")
    cb.cycle(buf, 2)
    eq(line(buf, 2), "- [ ] partial", "a state outside the cycle starts it over")
  end

  -- List kinds ---------------------------------------------------------------
  do
    local cases = {
      { "- [ ] a", "- [x] a" },
      { "* [ ] a", "* [x] a" },
      { "+ [ ] a", "+ [x] a" },
      { "1. [ ] a", "1. [x] a" },
      { "12) [ ] a", "12) [x] a" },
      { "    - [ ] nested", "    - [x] nested" },
      { "\t- [ ] tab", "\t- [x] tab" },
      { "> - [ ] quoted", "> - [x] quoted" },
      { "- [ ]", "- [x]" },
      { "- [ ] ünïcode [ ] again", "- [x] ünïcode [ ] again" },
      { "- [ ] crlf\r", "- [x] crlf\r" },
    }
    for _, c in ipairs(cases) do
      local buf = buffer({ c[1] })
      ok(cb.cycle(buf, 1), "a box: " .. c[1])
      eq(line(buf, 1), c[2], "only the state changed: " .. c[1])
    end
  end

  -- Not a box ----------------------------------------------------------------
  do
    local cases = {
      "plain text",
      "[ ] no list marker",
      "- no box",
      "- [x](https://example.com) a link",
      "- [a] not a state",
      "- [ ]text without a space",
      "- [] empty",
    }
    for _, text in ipairs(cases) do
      local buf = buffer({ text })
      eq(cb.cycle(buf, 1), false, "no box: " .. text)
      eq(line(buf, 1), text, "untouched: " .. text)
    end

    local buf = buffer({
      "```md",
      "- [ ] example",
      "```",
      "- [ ] real",
      "~~~",
      "```",
      "- [ ] inner",
      "~~~",
      "- [ ] last",
    })
    eq(cb.cycle(buf, 2), false, "a box in a fence is an example")
    eq(line(buf, 2), "- [ ] example", "the fenced example stays")
    ok(cb.cycle(buf, 4), "a box after the fence")
    eq(cb.cycle(buf, 7), false, "another fence char does not close a fence")
    ok(cb.cycle(buf, 9), "a box after the tilde fence")

    -- inline code at the start of a line opens no fence (markdown.util.fence, the renderer's rules)
    buf = buffer({ "```inline``` is how code reads", "- [ ] task" })
    ok(cb.cycle(buf, 2), "a box below inline code is a task")
    eq(line(buf, 2), "- [x] task", "and it steps")

    buf = buffer({ "- [ ] read only" })
    vim.bo[buf].modifiable = false
    eq(cb.cycle(buf, 1), false, "a read-only buffer is refused, not an error")
    vim.bo[buf].modifiable = true
  end

  -- Direct states and configuration ------------------------------------------
  do
    local buf = buffer({ "- [ ] a" })
    ok(cb.set("~", buf, 1), "set writes a state directly")
    eq(line(buf, 1), "- [~] a", "set: cancelled")
    ok(cb.set("~", buf, 1), "set to the state it has is no failure")

    config.setup({ checkbox = { states = { " ", "ö", "x" } } })
    buf = buffer({ "- [ ] a" })
    cb.cycle(buf, 1)
    eq(line(buf, 1), "- [ö] a", "a configured multi-byte state")
    cb.cycle(buf, 1)
    eq(line(buf, 1), "- [x] a", "a multi-byte state is replaced whole")

    config.setup({ checkbox = { states = { "two", 3 } } })
    eq(table.concat(cb.states(), ","), " ,x,~", "a wrong list falls back to the default")
    config.setup({})
  end

  -- Keys ---------------------------------------------------------------------
  do
    config.setup({})
    local keymaps = require("markdown.bindings.keymaps")
    local buf = buffer({ "text", "- [ ] task" })
    keymaps.apply(buf)
    for _, lhs in ipairs({ "<C-CR>", "<S-CR>", "<leader>mx" }) do
      ok(vim.fn.maparg(lhs, "n") ~= "" or vim.fn.mapcheck(lhs, "n") ~= "", "mapped: " .. lhs)
    end
    api.nvim_win_set_cursor(0, { 2, 9 })
    api.nvim_feedkeys(api.nvim_replace_termcodes("<C-CR>", true, false, true), "x", false)
    eq(line(buf, 2), "- [x] task", "<C-CR> steps the box from the end of the line")
    api.nvim_feedkeys(api.nvim_replace_termcodes("<S-CR>", true, false, true), "x", false)
    eq(line(buf, 2), "- [~] task", "<S-CR> steps it too")
    api.nvim_win_set_cursor(0, { 1, 0 })
    api.nvim_feedkeys(api.nvim_replace_termcodes("<C-CR>", true, false, true), "x", false)
    eq(line(buf, 1), "text", "on a line without a box the key does nothing")
    eq(vim.v.errmsg:match("^E%d+") and vim.v.errmsg or "", "", "and raises nothing")

    config.setup({ keymaps = { checkbox_cycle_ctrl = false, checkbox_cycle_shift = "<F7>" } })
    buf = buffer({ "- [ ] task" })
    keymaps.apply(buf)
    eq(vim.fn.maparg("<C-CR>", "n"), "", "a key can be switched off")
    ok(
      vim.fn.maparg("<F7>", "n") ~= "" or #vim.fn.maparg("<F7>", "n", false, true) > 0,
      "and moved"
    )
    config.setup({})
  end

  -- Double-click -------------------------------------------------------------
  do
    local actions = require("markdown.bindings.actions")
    local handler = require("markdown.handler")
    local real = handler.handle_cursor_action
    local calls = 0
    handler.handle_cursor_action = function() calls = calls + 1 end

    local buf = buffer({ "  - [ ] task" })
    api.nvim_win_set_cursor(0, { 1, 5 })
    actions.cursor_action_2click()
    eq(line(buf, 1), "  - [x] task", "a double-click on the box steps it")
    eq(calls, 0, "and is not a cursor action")

    for _, col in ipairs({ 1, 3, 9 }) do
      api.nvim_win_set_cursor(0, { 1, col })
      actions.cursor_action_2click()
      eq(line(buf, 1), "  - [x] task", "a double-click beside the box leaves it, col " .. col)
    end
    eq(calls, 3, "a double-click elsewhere stays the cursor action")
    handler.handle_cursor_action = real
  end

  -- Menu ---------------------------------------------------------------------
  do
    config.setup({})
    local menu = require("markdown.integrations.menu")
    local function by_name()
      local out = {}
      for _, it in ipairs(menu.items()) do
        out[it.name] = it
      end
      return out
    end

    local buf = buffer({ "text", "- [ ] task" })
    api.nvim_win_set_cursor(0, { 1, 0 })
    eq(by_name()["Cycle Checkbox"], nil, "no checkbox entry on a line without a box")

    api.nvim_win_set_cursor(0, { 2, 0 })
    local items = by_name()
    ok(items["Cycle Checkbox"], "the cycle entry on a box")
    ok(
      items["Checkbox: Open"] and items["Checkbox: Done"] and items["Checkbox: Cancelled"],
      "the direct states"
    )

    -- A menu runs its entry from elsewhere: the entry keeps the row it was built for.
    api.nvim_win_set_cursor(0, { 1, 0 })
    items["Checkbox: Cancelled"].cmd()
    eq(line(buf, 2), "- [~] task", "the direct state lands on the row of the box")
    items["Cycle Checkbox"].cmd()
    eq(line(buf, 2), "- [ ] task", "the cycle entry too")

    config.setup({ menu = { checkbox = false } })
    api.nvim_win_set_cursor(0, { 2, 0 })
    eq(by_name()["Cycle Checkbox"], nil, "menu.checkbox = false opts out")
    config.setup({})
  end

  -- Rendering ----------------------------------------------------------------
  do
    config.setup({})
    local render = require("markdown.core.render")
    -- The cursor row shows its raw text, so the boxes sit below it.
    local buf = buffer({ "cursor row", "- [~] cancelled", "- [ ] open", "1. [~] numbered" })
    render.enable(buf)
    render.refresh(buf)
    vim.wait(200, function() return false end)
    local texts = {}
    for _, m in ipairs(api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true })) do
      local cc = m[4].conceal
      if cc and cc ~= "" then texts[cc] = (texts[cc] or 0) + 1 end
    end
    render.disable(buf)
    eq(texts["☒"], 2, "a cancelled box has its own icon, bullet and numbered")
    eq(texts["☐"], 1, "an open box keeps its icon")
    eq(texts["☑"], nil, "a cancelled box is not drawn as done")
    eq(type(config.get().render.checkboxes.cancelled), "string", "the icon is an option")
  end
end
