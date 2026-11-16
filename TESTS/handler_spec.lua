-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- docs/TESTS/handler_spec.lua — cursor-action handler: silent mode for mouse
-- invocation (a "no target" miss should not notify when triggered by the mouse).
---@diagnostic disable: missing-fields

return function(H)
  local eq = H.eq

  -- Stub util.notify to record calls without depending on lib.nvim/vim.notify.
  package.loaded["markdown.util.notify"] = nil
  package.loaded["markdown.handler"] = nil
  local calls = {}
  package.loaded["markdown.util.notify"] = {
    create = function()
      return {
        info = function(msg) calls[#calls + 1] = { level = "info", msg = msg } end,
        warn = function(msg) calls[#calls + 1] = { level = "warn", msg = msg } end,
        error = function(msg) calls[#calls + 1] = { level = "error", msg = msg } end,
        debug = function() end,
      }
    end,
  }
  local handler = require("markdown.handler")

  local buf = H.scratch("markdown")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "just plain prose, no links or targets here" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  handler.handle_cursor_action({ silent = true })
  eq(#calls, 0, "silent mode: no notification on a miss")

  handler.handle_cursor_action()
  eq(#calls, 1, "default mode: one notification on a miss")
  eq(calls[1].level, "info", "miss notification is info-level")

  -- A plain `[text](target)` link is not an image (regression: the fallback
  -- pattern in handler/image.lua used to match ANY markdown link, not just
  -- `![alt](src)`, so every link was misclassified as an image and opened
  -- externally instead of via :edit).
  do
    local image = require("markdown.handler.image")
    eq(
      image.is_image_line("[Review answer](C:/repos/foo/bar.md)"),
      false,
      "plain link is not an image"
    )
    eq(
      image.is_image_line("![alt](C:/repos/foo/pic.png)"),
      true,
      "real image syntax still recognized"
    )
  end

  -- A Windows drive-letter absolute path (`C:/…`) is a file target, not a
  -- URI scheme (regression: `^%w[%w+.-]*:` matched `C:` the same as `http:`).
  do
    local is_extern = require("markdown.anchor.is_html_extern_anchor_line")
    local extern = is_extern("[Review answer](C:/repos/foo/bar.md)")
    eq(type(extern), "table", "drive-letter path recognized as a file target")
    eq(extern.target, "C:/repos/foo/bar.md", "extracted target unchanged")

    -- Real URI schemes must still be rejected (not treated as file targets).
    eq(is_extern("[mail](mailto:foo@bar.com)"), nil, "mailto: still rejected")
    eq(is_extern("[site](http://example.com)"), nil, "http: still rejected")
  end

  -- End-to-end: double-clicking a `[text](C:/…)` link opens the target via
  -- :edit in the current window, never via the system's default application.
  do
    package.loaded["markdown.handler"] = nil
    local h2 = require("markdown.handler")

    local target = vim.fn.tempname() .. "_mdnvim_target.md"
    local fh = io.open(target, "w")
    if fh then
      fh:write("# target")
      fh:close()
    end
    -- Canonicalize now that the file exists. On macOS $TMPDIR is under /var,
    -- a symlink to /private/var: tempname() answers the unresolved spelling
    -- while the buffer name Neovim reports after opening the file answers the
    -- resolved one, so comparing the two below would compare two spellings of
    -- one file and fail while the handler is doing the right thing.
    target = ((vim.uv or vim.loop).fs_realpath(target) or target)
    local target_slash = (target:gsub("\\", "/"))
    -- Force a drive-letter-style prefix regardless of host OS so the
    -- regression (Windows-only) is exercised everywhere the suite runs.
    local drive_target = target_slash:match("^%a:/") and target_slash or ("C:" .. target_slash)

    local system_opened = nil
    local orig_ui_open = vim.ui.open
    -- A test double over typed `vim.ui` surface: replacing the field is the
    -- point of the case, not a second definition of it.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.open = function(p)
      system_opened = p
      return true, nil
    end

    local run_ok, run_err = pcall(function()
      local drive_buf = H.scratch("markdown")
      vim.api.nvim_buf_set_lines(
        drive_buf,
        0,
        -1,
        false,
        { "[Review answer](" .. drive_target .. ")" }
      )
      vim.api.nvim_win_set_cursor(0, { 1, 5 })
      h2.handle_cursor_action({ silent = true, mouse = true })
    end)

    vim.ui.open = orig_ui_open
    pcall(vim.fn.delete, target)

    if not run_ok then error(run_err, 0) end
    eq(system_opened, nil, "drive-letter .md link opens via :edit, not the system app")
    eq(vim.api.nvim_buf_get_name(0), target, "current buffer is the linked file")
  end

  -- A line with a plain parenthesis that names a file (`(TCShell.exe ...)`)
  -- before two https links: `ma` / double-click on a link opens exactly that
  -- link (regression: the external-anchor branch took the first `%b()` of the
  -- whole line, resolved `TCShell.exe` as a file next to the buffer and
  -- warned "External anchor: target file not found").
  do
    local is_extern = require("markdown.anchor.is_html_extern_anchor_line")
    local line = "Start it (TCShell.exe in your Tosca Commander folder, see Tricentis/Tosca Testsuite) "
      .. "and read [Guide](https://example.com/guide) or [Docs](https://example.com/docs)."
    eq(is_extern(line), nil, "a bare parenthesis is no link target")
    local docs_col = line:find("[Docs]", 1, true) + 1 -- 0-based column inside the link
    eq(is_extern(line, docs_col), nil, "cursor on an https link: not an external file")

    local mixed = "See (TCShell.exe) [notes](notes.md) and [web](https://example.com/x)"
    local r = is_extern(mixed)
    eq(r and r.target, "notes.md", "without a cursor link the first file link counts")
    eq(is_extern(mixed, mixed:find("[web]", 1, true)), nil, "cursor on the URL link wins")
    r = is_extern(mixed, mixed:find("[notes]", 1, true))
    eq(r and r.target, "notes.md", "cursor on the file link")

    -- An HTML `src=` on a neighbouring line does not hijack a line that has
    -- markdown links of its own (the near-cursor scan is for HTML blocks).
    do
      local nbuf = H.scratch("markdown")
      vim.api.nvim_buf_set_lines(nbuf, 0, -1, false, { '<img src="pic.png">', line })
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      eq(is_extern(line, 0), nil, "a neighbouring src= does not claim a link line")
    end

    package.loaded["markdown.handler"] = nil
    local h3 = require("markdown.handler")
    local orig_open_target = h3.open_target
    local opened = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    h3.open_target = function(t) opened[#opened + 1] = t end
    local before = #calls
    local run_ok, run_err = pcall(function()
      local lbuf = H.scratch("markdown")
      vim.api.nvim_buf_set_lines(lbuf, 0, -1, false, { line })
      vim.api.nvim_win_set_cursor(0, { 1, docs_col })
      h3.handle_cursor_action({ silent = true, mouse = true })
      vim.api.nvim_win_set_cursor(0, { 1, line:find("[Guide]", 1, true) + 2 })
      h3.handle_cursor_action()
    end)
    h3.open_target = orig_open_target
    if not run_ok then error(run_err, 0) end
    eq(
      table.concat(opened, " "),
      "https://example.com/docs https://example.com/guide",
      "the link under the cursor opens"
    )
    eq(#calls, before, "no 'External anchor' warning for https links")
  end

  -- Restore the real notify module so later specs (if any run after this one
  -- in the same process) are unaffected.
  package.loaded["markdown.util.notify"] = nil
  package.loaded["markdown.handler"] = nil
end
