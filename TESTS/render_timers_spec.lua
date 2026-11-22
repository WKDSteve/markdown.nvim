-- TESTS/render_timers_spec.lua — rendering leaves no libuv timer running once it is done.
--
-- The render and table-grid debounces are one-shot `vim.defer_fn` timers: armed by an edit, closed when they
-- fired. A timer that stayed active (a repeating one, or one never closed) keeps `settle` of every sheet that
-- renders from ever being idle ("not idle after N ms: handles (timer=1)"). color_my_ascii, a dependency, keeps
-- a 30 s cleanup timer for ever by design once it is set up; it is set up before the count is taken, as the
-- sheets do.
---@diagnostic disable: need-check-nil

return function(H)
  local ok = H.ok
  local api = vim.api

  ---@return integer
  local function active_timers()
    local n = 0
    vim.uv.walk(function(h)
      if h:get_type() == "timer" and h:is_active() and not h:is_closing() then n = n + 1 end
    end)
    return n
  end

  local cma_ok, cma = pcall(require, "color_my_ascii")
  if cma_ok and cma.ensure_setup then cma.ensure_setup() end

  require("markdown").setup({})
  local render = require("markdown.core.render")
  local table_render = require("markdown.core.table_render")

  local buf = H.scratch("markdown")
  api.nvim_set_current_buf(buf)
  api.nvim_buf_set_lines(buf, 0, -1, false, {
    "# Title",
    "",
    "Some text with **bold** and `code`.",
    "",
    "| Name | Note       |",
    "| ---- | ---------- |",
    "| a    | first row  |",
  })
  -- the FileType autocmds of markdown.nvim and of color_my_ascii run here; the count is taken after them
  vim.bo[buf].filetype = "markdown"
  vim.wait(300, function() return false end, 20)
  local base = active_timers()

  render.enable(buf)
  table_render.enable(buf)
  api.nvim_buf_set_lines(buf, 2, 3, false, { "Changed text with **bold**." })
  api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  ok(active_timers() > base, "an edit arms a debounce timer (the count sees a running timer)")

  local idle = vim.wait(2000, function() return active_timers() <= base end, 20)
  ok(idle, "the debounce timers end after they fired: no timer of the renderer is left running")

  render.disable(buf)
  table_render.disable(buf)
  vim.wait(300, function() return false end, 20)
  -- `<=`: a one-shot timer of the setup that still ran when `base` was taken may have ended since
  ok(active_timers() <= base, "disabling leaves no timer running either")
end
