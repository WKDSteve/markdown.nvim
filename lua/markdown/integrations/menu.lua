---@module 'markdown.integrations.menu'
---@brief Context-aware menu entries (soft, opt-in integration).
---@description
--- markdown.nvim does not depend on a menu plugin. Instead it *provides* a list
--- of entries in the context-menu entry shape (`{ name, cmd, rtxt, icon }`, plus
--- `{ name = "separator" }`), and a host — typically the user's menu dispatcher —
--- composes them into its own menu for markdown buffers, e.g.:
--- >
---   local items = require("markdown.integrations.menu").items()
---   -- prepend `items` to your custom menu table, then menu.open(composed)
--- <
--- Entries are context-aware: the fold actions only appear when the cursor sits
--- on an ATX heading, the checkbox actions only on a checkbox line. Everything is
--- opt-out via `config.menu` (see DEFAULTS).

local nerd = require("lib.nvim.ui.nerd_font")

local M = {}

--- One glyph per entry, drawn in the renderer's icon column (`icon`), never in
--- the label: a label that starts with spaces or a glyph indents its row past
--- every other one. ASCII fallback without a declared Nerd Font.
---@type table<string, string>
local ICON = {
  fold = nerd.glyph("F054E", "-"), -- unfold-less-horizontal
  unfold = nerd.glyph("F054F", "+"), -- unfold-more-horizontal
  cycle = nerd.glyph("F0C52", "x"), -- checkbox-marked-outline
  state = nerd.glyph("F0131", "o"), -- checkbox-blank-outline
  toc = nerd.glyph("F027B", "1"), -- format-list-numbered
  refs = nerd.glyph("F0337", "L"), -- link
  mdview = nerd.glyph("F0208", "v"), -- eye
  image = nerd.glyph("F02E9", "I"), -- image-multiple
  markdown = nerd.glyph("F0354", "M"), -- language-markdown
}

--- Whether the cursor is currently on an ATX heading line (`#`, `##`, …).
---@return boolean
local function on_heading() return vim.api.nvim_get_current_line():match("^%s*#+%s") ~= nil end

--- Menu labels of the states the default cycle knows; another state shows as itself.
---@type table<string, string>
local STATE_LABELS = { [" "] = "Open", x = "Done", ["~"] = "Cancelled" }

--- The checkbox entries for the cursor line, empty on a line without a box. They
--- capture buffer and row: a menu runs its entry after the cursor may have moved.
---@return table[]
local function checkbox_items()
  local checkbox = require("markdown.core.checkbox")
  local buf = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  if not checkbox.at(buf, row) then return {} end
  local out = {
    {
      name = "Cycle Checkbox",
      cmd = function() checkbox.cycle(buf, row) end,
      rtxt = "<C-CR>",
      icon = ICON.cycle,
    },
  }
  for _, state in ipairs(checkbox.states()) do
    out[#out + 1] = {
      name = "Checkbox: " .. (STATE_LABELS[state] or ("[" .. state .. "]")),
      cmd = function() checkbox.set(state, buf, row) end,
      icon = ICON.state,
    }
  end
  return out
end

--- Whether the buffer can go to mdview.nvim: its `:MDView` command exists (the
--- same test `:Markdown mdview` makes) and the buffer has a file to show.
---@return boolean
local function mdview_available()
  return vim.fn.exists(":MDView") == 2 and vim.api.nvim_buf_get_name(0) ~= ""
end

--- Whether images.nvim is installed (`:Markdown image paste` delegates to it).
---@return boolean
local function images_available()
  local ok, mod = pcall(require, "images")
  return ok and type(mod) == "table" and type(mod.paste) == "function"
end

--- Whether a host that asks first (ui.nvim's `ui.menu`) may show the
--- Markdown fly-out: `integrations.ui_menu` is not false and the `menu` group
--- is not switched off. `items()`/`submenu()` themselves stay governed by
--- `menu` alone, so other hosts are unaffected by `ui_menu`.
---@return boolean
function M.enabled()
  local cfg = require("markdown.config").get()
  if (cfg.integrations or {}).ui_menu == false then return false end
  return (cfg.menu or {}).enable ~= false
end

--- Build the markdown menu entries for the current context.
--- Returns an empty list when the integration (or every sub-entry) is disabled,
--- so a host can safely `vim.list_extend` it unconditionally.
---@param opts? { force_fold?: boolean }  force_fold: include fold entries even off a heading
---@return table[]  context-menu entry list (possibly empty)
function M.items(opts)
  opts = opts or {}
  local cfg = require("markdown.config").get()
  local mcfg = cfg.menu or {}
  if mcfg.enable == false then return {} end

  local actions = require("markdown.bindings.actions")
  local items = {}

  -- Fold controls — only meaningful on a heading (or when forced).
  if mcfg.fold ~= false and (opts.force_fold or on_heading()) then
    items[#items + 1] = {
      name = "Fold / Unfold Heading",
      cmd = actions.fold_toggle,
      rtxt = "za",
      icon = ICON.fold,
    }
    items[#items + 1] = {
      name = "Fold below H2 (toggle)",
      cmd = actions.fold_h2plus,
      rtxt = "zk",
      icon = ICON.fold,
    }
    items[#items + 1] = {
      name = "Unfold All",
      cmd = actions.unfold_all,
      rtxt = "zu",
      icon = ICON.unfold,
    }
  end

  -- Checkbox actions: only on a checkbox line.
  if mcfg.checkbox ~= false then
    local boxes = checkbox_items()
    if #boxes > 0 and #items > 0 then items[#items + 1] = { name = "separator" } end
    vim.list_extend(items, boxes)
  end

  -- Document-level actions (always available in a markdown buffer).
  local doc = {}
  if mcfg.toc ~= false then
    doc[#doc + 1] = {
      name = "Insert / Refresh TOC",
      cmd = actions.toc,
      rtxt = "<leader>toc",
      icon = ICON.toc,
    }
  end
  if mcfg.refs ~= false then
    doc[#doc + 1] = {
      name = "Sync References",
      cmd = function() require("markdown.core.refs").reconcile() end,
      icon = ICON.refs,
    }
  end
  -- Hand-overs to sister plugins: only offered when that plugin is there, so the
  -- menu never lists a row that can only warn.
  if mcfg.mdview ~= false and mdview_available() then
    doc[#doc + 1] = {
      name = "Preview in mdview",
      cmd = function() require("markdown.commands.mdview").run({}) end,
      icon = ICON.mdview,
    }
  end
  if mcfg.image ~= false and images_available() then
    doc[#doc + 1] = {
      name = "Paste image",
      cmd = function() require("markdown.commands.image").run({ "paste" }) end,
      icon = ICON.image,
    }
  end

  if #items > 0 and #doc > 0 then items[#items + 1] = { name = "separator" } end
  vim.list_extend(items, doc)

  return items
end

--- Convenience: the markdown entries wrapped as a single nested submenu entry,
--- for hosts that prefer a "Markdown ▸" fly-out instead of inline entries.
--- Returns nil when there is nothing to show.
---@param label? string  submenu label (default "Markdown")
---@return table|nil
function M.submenu(label)
  local items = M.items()
  if #items == 0 then return nil end
  return { name = label or "Markdown", hl = "Exblue", icon = ICON.markdown, items = items }
end

return M
