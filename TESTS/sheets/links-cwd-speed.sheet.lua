-- `:Markdown links show cwd` lists every *.md below the cwd with lib.nvim's walker (collect_recursive
-- .files_with_ext) instead of globpath("**/*.md"), which walked node_modules and took seconds on Windows
-- (4 s on a 7 000-file vault, 129 ms after). This sheet keeps that acceptance measurement: a generated project of
-- 300 notes plus 1 000 in node_modules and 100 in a dot folder; the command reaches the picker within `max` and
-- the picker lists the 300 links of the project and none of the others. The picker is a recording stand-in
-- (`markdown.util.picker`): what a person sees in it is the business of the picker sheets.
local SETUP = [[vim.opt.shortmess:append("I")
  vim.o.swapfile = false
  require("markdown").setup({})
  _G.root = vim.fs.normalize(vim.fn.tempname())
  -- libuv, not writefile: a test case has 10 s, and writefile of 1 400 files took most of it on Windows CI
  local uv = vim.uv
  local function write(dir, n, host)
    vim.fn.mkdir(dir, "p")
    for i = 1, n do
      local fd = assert(uv.fs_open(("%s/note%04d.md"):format(dir, i), "w", 420))
      uv.fs_write(fd, table.concat({ "# note " .. i, "", ("[link](https://%s.test/%d)"):format(host, i), "" }, "\n"))
      uv.fs_close(fd)
    end
  end
  for d = 1, 30 do write(("%s/notes/part%02d"):format(_G.root, d), 10, "project") end
  for d = 1, 10 do write(("%s/node_modules/pkg%02d/docs"):format(_G.root, d), 100, "vendored") end
  write(_G.root .. "/.cache/old", 100, "hidden")
  vim.cmd.cd(vim.fn.fnameescape(_G.root))
  -- :Markdown is a command of a Markdown buffer
  vim.cmd.edit("notes/part01/note0001.md")
  _G.shown = nil
  package.loaded["markdown.util.picker"] = {
    select = function(items)
      _G.took = vim.uv.hrtime() / 1e6 - _G.t0
      _G.shown = items
    end,
  }]]

return {
  id = "links.cwd-speed",
  title = ":Markdown links show cwd: 300 notes listed fast, node_modules and dot folders left out",
  task = "pickers.nvim/abnahme-schnelle-dateilisten",
  engine = "rpc",
  sizes = { { rows = 24, cols = 100 } },
  steps = {
    { lua = SETUP, timeout = 120000, note = "300 notes, 1 000 in node_modules, 100 in .cache" },
    {
      lua = [[_G.t0 = vim.uv.hrtime() / 1e6; vim.cmd("Markdown links show cwd")]],
      note = ":Markdown links show cwd",
    },
    { wait = "_G.shown ~= nil", timeout = 30000, note = "the picker opens" },
    { measure = "_G.took", name = "links show cwd (300 notes)", unit = "ms", max = 5000 },
    {
      expect = [[(function()
        local hosts = {}
        for _, lk in ipairs(_G.shown) do
          local host = lk.target:match("^https://(%w+)%.test/")
          hosts[host or "?"] = (hosts[host or "?"] or 0) + 1
        end
        if not vim.deep_equal(hosts, { project = 300 }) then error("links by host: " .. vim.inspect(hosts), 0) end
        return true
      end)()]],
      note = "the 300 links of the project, none from node_modules or .cache",
    },
    { lua = [[vim.cmd.cd("-"); vim.fn.delete(_G.root, "rf")]], timeout = 60000 },
  },
}
