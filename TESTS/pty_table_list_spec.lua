-- TESTS/pty_table_list_spec.lua -- `:Markdown table list` in the REAL fzf-lua window (tier 2.5).
--
-- A real Neovim runs inside tmux (WSL on Windows, testing.nvim's `testing.pty`) with markdown.nvim,
-- pickers.nvim on its fzf engine and fzf-lua; the screen of the terminal is read back: both tables are
-- listed with a preview, `<M-c>` switches the preview from the file around the table to the table alone and
-- back, and choosing the second entry jumps to the second table. The snacks engine is the sheet
-- TESTS/sheets/table-list-snacks.sheet.lua. Skipped (a reported n/a, never green) without tmux, the fzf
-- binary on the host of tmux, fzf-lua or pickers.nvim on this machine, or testing.nvim on the runtimepath.

---@param H table harness
return function(H)
  local ESC = string.char(27)
  local BS = string.char(92)

  local ok_pty, pty = pcall(require, "testing.pty")
  if not ok_pty then
    print("n/a  testing.nvim is not on the runtimepath (testing.pty)")
    return
  end
  local available, reason = pty.available()
  if not available then
    print("n/a  " .. reason)
    return
  end

  ---Windows path -> the path WSL sees (`E:\x` -> `/mnt/e/x`); Linux paths stay.
  ---@param path string
  ---@return string
  local function host_path(path)
    path = path:gsub(BS, "/")
    local drive, rest = path:match("^(%a):(.*)$")
    if not drive then return path end
    return "/mnt/" .. drive:lower() .. rest
  end

  local this = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p"))
  local root = vim.fs.dirname(vim.fs.dirname(this))

  ---A plugin checkout: the runtimepath of this editor, then the usual places.
  ---@param name string
  ---@param module string
  ---@return string|nil
  local function checkout(name, module)
    local rel = "lua/" .. module:gsub("%.", "/")
    local found = vim.api.nvim_get_runtime_file(rel .. "/init.lua", false)[1]
      or vim.api.nvim_get_runtime_file(rel .. ".lua", false)[1]
    if found then return (vim.fn.fnamemodify(found, ":p"):gsub(BS, "/"):match("^(.*)/lua/")) end
    local places = {
      vim.fs.dirname(root) .. "/" .. name,
      root .. "/.deps/" .. name,
      (vim.uv.os_getenv("LOCALAPPDATA") or "") .. "/nvim-data/lazy/" .. name,
      (vim.uv.os_getenv("HOME") or "") .. "/.local/share/nvim/lazy/" .. name,
    }
    for _, p in ipairs(places) do
      if vim.fn.isdirectory(p .. "/lua") == 1 then return (p:gsub(BS, "/")) end
    end
    return nil
  end

  local fzf_lua, pickers, lib =
    checkout("fzf-lua", "fzf-lua"),
    checkout("pickers.nvim", "pickers"),
    checkout("lib.nvim", "lib.nvim")
  if not (fzf_lua and pickers and lib) then
    print("n/a  fzf-lua, pickers.nvim or lib.nvim is not installed on this machine")
    return
  end
  -- the fzf binary on the host of tmux
  local argv = { "sh", "-c", "command -v fzf" }
  if require("testing.platform").is_windows() then
    argv = { "wsl" }
    local distro = vim.uv.os_getenv("TESTING_WSL_DISTRO")
    if distro and distro ~= "" then vim.list_extend(argv, { "-d", distro }) end
    vim.list_extend(argv, { "--exec", "sh", "-c", "command -v fzf" })
  end
  if vim.system(argv, { text = true }):wait(15000).code ~= 0 then
    print("n/a  the fzf binary is not installed on the host of tmux")
    return
  end

  ---The screen without colour sequences, which split words.
  local function plain(s) return (s:screen():gsub(ESC .. "%[[%d;:]*m", "")) end
  local function waits(s, needle, ms)
    local deadline = vim.uv.hrtime() + ms * 1e6
    repeat
      if plain(s):find(needle, 1, true) then return true end
      vim.wait(100)
    until vim.uv.hrtime() > deadline
    return false
  end

  local session, err = pty.open({
    "env",
    "MARKDOWN_PTY_ROOT=" .. host_path(root),
    "MARKDOWN_PTY_RTP="
      .. table.concat({ host_path(lib), host_path(pickers), host_path(fzf_lua) }, ","),
    "nvim",
    "--clean",
    "-c",
    "luafile " .. host_path(root) .. "/TESTS/pty/init.lua",
  }, { cols = 110, rows = 30 })
  H.ok(session ~= nil, "the session starts: " .. tostring(err))
  if not session then return end

  local function finish(msg, cond)
    if not cond then
      local shown = plain(session)
      session:close()
      H.ok(false, msg .. ":\n" .. shown)
    end
  end

  finish("the terminal editor got ready", waits(session, "PTY-READY", 25000))
  session:send({ ":Markdown table list", "Enter" })
  finish("the fzf window opened", waits(session, "Markdown tables", 15000))
  finish("both tables are listed", waits(session, "doc.md:10  X | Y", 10000))
  local listed = plain(session)
  finish("the first entry too", listed:find("doc.md:3  Name | Note", 1, true) ~= nil)
  finish("the preview shows the file around the table", waits(session, "[normal] table", 10000))
  finish("the preview has the file's text", waits(session, "# Doc", 10000))

  session:send({ "M-c" })
  finish("the preview switched to the table alone", waits(session, "normal [table]", 10000))
  finish("it shows the formatted grid", waits(session, "┌", 10000))
  session:send({ "M-c" })
  finish("and back to the file", waits(session, "[normal] table", 10000))

  session:send({ "Down" })
  vim.wait(500)
  session:send({ "Enter" })
  local deadline = vim.uv.hrtime() + 10e9
  while plain(session):find("Markdown tables", 1, true) and vim.uv.hrtime() < deadline do
    vim.wait(100)
  end
  finish("the picker closed", not plain(session):find("Markdown tables", 1, true))
  finish("choosing the second entry jumped to line 10", waits(session, "10,1", 10000))
  session:close()
end
