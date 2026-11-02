-- TESTS/support/plugins.lua -- finds optional plugins for the test sheets (TESTS/sheets/*.sheet.lua).
--
-- Loaded INSIDE the child editor of a sheet (`dofile(vim.fn.getcwd() .. "/TESTS/support/plugins.lua")`):
-- sheets are data and cannot require anything while they are read. snacks.nvim, fzf-lua and pickers.nvim
-- are not dependencies of markdown.nvim and CI does not check them out; a sheet that needs one lists
-- `requires = { { lua = "...have(...)", reason = ... } }`, so it is a reported n/a without them.

local P = {}

---Directories that may hold a plugin checkout, in order.
---@return string[]
local function search_dirs()
  local dirs = {}
  local function add(d)
    if d and d ~= "" then dirs[#dirs + 1] = vim.fs.normalize(d) end
  end
  add(vim.env.MARKDOWN_PLUGINS_DIR)
  local cwd = vim.fn.getcwd()
  add(cwd .. "/.deps")
  add(vim.fs.dirname(cwd))
  -- the child's own stdpath is a sandbox, so look where a plugin manager of the real user installs
  add(vim.env.LOCALAPPDATA and (vim.env.LOCALAPPDATA .. "/nvim-data/lazy"))
  add(vim.env.HOME and (vim.env.HOME .. "/.local/share/nvim/lazy"))
  return dirs
end

---Where the plugin `name` (a directory name such as `snacks.nvim`) is installed, or nil.
---@param name string
---@return string|nil
function P.find(name)
  for _, d in ipairs(search_dirs()) do
    if vim.fn.isdirectory(d .. "/" .. name .. "/lua") == 1 then return d .. "/" .. name end
  end
  return nil
end

---Is every named plugin installed?
---@param names string[]
---@return boolean
function P.have(names)
  for _, n in ipairs(names) do
    if not P.find(n) then return false end
  end
  return true
end

---Put the named plugins on the runtimepath; make the sandboxed stdpath directories exist (plugins write
---their logs and state there, and a multi-line warning would wait for <Enter> on the attached UI).
---@param names string[]
function P.use(names)
  for _, d in ipairs({ "data", "state", "cache" }) do
    vim.fn.mkdir(vim.fn.stdpath(d), "p")
  end
  for _, n in ipairs(names) do
    local dir = P.find(n)
    if dir then vim.opt.rtp:append(dir) end
  end
end

return P
