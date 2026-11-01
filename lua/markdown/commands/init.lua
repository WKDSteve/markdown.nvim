---@module 'markdown.commands'
local M = {}

local notify = require("markdown.util.notify").create("[markdown.commands]")

---@class markdown.Subcommand
---@field run fun(argv: string[], ctx?: table)
---@field features? string[]  Enabled if ANY is on; defaults to the subcommand's own name
---@field mod? string          Module exposing `complete(arglead, cmdline)` for nested completion
---@field nested? boolean      The completer reads the cmdline, so deeper slots keep delegating to it

--- A subcommand backed by a `markdown.commands.<name>` module (`run` plus, optionally,
--- `complete`).
---@param name string
---@param nested? boolean  `true` when its completer reads the cmdline and so has
---                        something to say beyond its own sub-subcommand slot; the
---                        rest only know that first slot, and delegating deeper
---                        would just echo their names into an argument position.
---@param features? string[]
---@return markdown.Subcommand
local function module_command(name, nested, features)
  local mod = "markdown.commands." .. name
  return { run = require(mod).run, mod = mod, nested = nested, features = features }
end

-- One table for run, completion and gating, so a subcommand cannot be added to one
-- and forgotten in another (`format` once was: the dispatcher ran it, `<Tab>`
-- completed it, and the composer answered "unknown subcommand"). A subcommand name
-- usually equals its gating feature; a few map to several (enabled if ANY is on),
-- which keeps "just enable tableview" == the full table surface.
---@type table<string, markdown.Subcommand>
local commands = {
  links = module_command("links", true),
  -- `toc` has no completer of its own: past its name it takes no candidates.
  toc = { run = require("markdown.commands.toc").run },
  refs = module_command("refs", true),
  table = module_command("table", true, { "table", "tableview" }),
  render = module_command("render"),
  preview = module_command("preview"),
  mdview = module_command("mdview"),
  create = module_command("create"),
  scope = module_command("scope"),
  list = module_command("list", true),
  image = module_command("image"),
  export = module_command("export"),
  headings = module_command("headings", true),
  -- `nested = true`: `format` takes an open-ended run of ops/flags, so every
  -- slot after the first should keep offering the same candidate set (like
  -- `table format`'s own multi-slot completion, one level up).
  format = module_command("format", true),
  headline_spacing = {
    run = function()
      local bufnr = vim.api.nvim_get_current_buf()
      require("markdown.core.headline_spacing").apply_headl_separators(bufnr, { notify = true })
    end,
  },
  gaps = {
    run = function()
      local bufnr = vim.api.nvim_get_current_buf()
      require("markdown.core.heading_gaps").check(bufnr, {})
    end,
    features = { "toc" },
  },
}

--- Whether the `:Markdown <command>` subcommand is enabled by feature gating.
---@param command string
---@return boolean
local function command_feature_enabled(command)
  local feat = require("markdown.config").feature_enabled
  local names = commands[command] and commands[command].features or { command }
  for _, n in ipairs(names) do
    if feat(n) then return true end
  end
  return false
end

--- Whether a subcommand is enabled by feature gating (`features` config).
---@param name string
---@return boolean
function M.enabled(name) return command_feature_enabled(name) end

--- Every subcommand name the dispatcher knows, sorted. `bindings/usrcmds.lua` builds the
--- composer routes of `:Markdown` from this, so a subcommand added to `commands` above is
--- reachable without a second list to keep in step (`format` once was not: the dispatcher
--- ran it, `<Tab>` completed it, the docs described it, and the composer answered
--- "unknown subcommand" because only the route list lacked it). Feature gating is separate.
---@return string[]
function M.names()
  local out = {}
  for name in pairs(commands) do
    out[#out + 1] = name
  end
  table.sort(out)
  return out
end

--- Dispatches a `:Markdown <subcommand> ...` invocation.
---@param argv string[]
---@param ctx? table  Optional context (e.g. range info) forwarded to the subcommand
---@return nil
function M.execute(argv, ctx)
  local command = argv[1]
  if not command then
    notify.info("Usage: :Markdown <subcommand>")
    return
  end

  local entry = commands[command]
  if not entry then
    notify.error(string.format("Unknown Markdown command: %s", command))
    return
  end

  -- Feature gate: subcommand names double as feature names (links, toc, table,
  -- render, preview, create, headline_spacing, scope, refs). A disabled feature
  -- reports instead of running. `table` is available under either the "table"
  -- or "tableview" feature so enabling just tableview keeps the whole table
  -- surface (view/format/new/mode/tableize) working standalone.
  if not command_feature_enabled(command) then
    notify.warn(string.format("Markdown %s: feature disabled via features config", command))
    return
  end

  table.remove(argv, 1)
  entry.run(argv, ctx)
end

--- Completion for `:Markdown`: subcommand names, then delegates to the
--- matched subcommand's own completion.
---@param arglead string
---@param cmdline string
---@param _cursorpos integer?
---@return string[]
function M.complete(arglead, cmdline, _cursorpos)
  -- Tokens already typed after ":Markdown".
  local tokens = vim.split(vim.trim(cmdline), "%s+")
  -- tokens[1] == "Markdown"; tokens[2] == first subcommand (if present).
  local first = tokens[2]
  -- The slot being completed: the token under the cursor, or one past the last
  -- committed token when nothing has been typed for it yet. Slot 2 is the
  -- subcommand itself, 3 its first argument.
  local slot = (arglead == "") and (#tokens + 1) or #tokens

  -- A first subcommand is complete and we are on one of its arguments.
  local entry = first and slot >= 3 and commands[first]
  if entry and entry.mod then
    if slot > 3 and not entry.nested then return {} end
    return require(entry.mod).complete(arglead, cmdline)
  end

  -- A subcommand with no nested completion of its own (toc, headline_spacing)
  -- takes no further candidates — its own name is not one of them.
  if slot >= 3 then return {} end

  local result = {}
  for name in pairs(commands) do
    if vim.startswith(name, arglead) and command_feature_enabled(name) then
      result[#result + 1] = name
    end
  end
  table.sort(result)
  return result
end

return M
