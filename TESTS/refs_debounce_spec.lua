-- TESTS/refs_debounce_spec.lua — core.refs.on_change: the live-mode debounce (lib.nvim.debounce.buffer).
---@diagnostic disable: need-check-nil

return function(H)
  local eq = H.eq
  local ok = H.ok

  package.loaded["markdown.core.refs"] = nil
  local config = require("markdown.config")
  local refs = require("markdown.core.refs")

  config.setup({ refs = { debounce_ms = 40 } })

  local calls = {}
  local real = refs.reconcile
  refs.reconcile = function(bufnr, opts)
    calls[#calls + 1] = { bufnr = bufnr, silent = opts and opts.silent }
  end

  local function new_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# t" })
    return buf
  end

  local a, b = new_buf(), new_buf()

  -- a burst of changes in one buffer folds into one reconcile, after the delay and not before it
  for _ = 1, 5 do
    refs.on_change(a)
  end
  eq(#calls, 0, "nothing runs synchronously")
  vim.wait(1000, function() return #calls > 0 end, 10)
  vim.wait(150, function() return #calls > 1 end, 10)
  eq(#calls, 1, "a burst of five changes reconciles once")
  eq(calls[1].bufnr, a, "the reconcile is for the changed buffer")
  eq(calls[1].silent, true, "the live reconcile is silent")

  -- two buffers keep independent timers
  calls = {}
  refs.on_change(a)
  refs.on_change(b)
  vim.wait(1000, function() return #calls >= 2 end, 10)
  eq(#calls, 2, "each buffer reconciles on its own timer")

  -- detach cancels a pending run
  calls = {}
  refs.on_change(a)
  refs.detach(a)
  vim.wait(200, function() return #calls > 0 end, 10)
  eq(#calls, 0, "detach cancels the pending reconcile")

  -- a wiped buffer is never reconciled
  calls = {}
  refs.on_change(b)
  vim.api.nvim_buf_delete(b, { force = true })
  vim.wait(200, function() return #calls > 0 end, 10)
  eq(#calls, 0, "a buffer wiped before the timer fires is skipped")

  -- a changed refs.debounce_ms is picked up by the next change
  config.setup({ refs = { debounce_ms = 5000 } })
  calls = {}
  refs.on_change(a)
  vim.wait(120, function() return #calls > 0 end, 10)
  eq(#calls, 0, "the longer delay is in effect")
  refs.detach(a)

  refs.reconcile = real
  config.setup({})
  ok(true, "done")
end
