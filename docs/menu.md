# Menu (nvzone/menu)

markdown.nvim ships context-aware entries for [nvzone/menu](https://github.com/nvzone/menu)
but does **not** depend on it. The plugin *owns* its entries; a host composes
them. Entries are context-aware — the fold actions only appear on a heading, the
checkbox actions only on a checkbox line — and opt-out via `config.menu`:

```lua
menu = {
  enable = true,
  fold   = true, -- Fold/Unfold Heading, Fold below H2 (toggle), Unfold All (on a heading)
  toc    = true, -- Insert/Refresh TOC
  refs   = true, -- Sync References
  checkbox = true, -- Cycle Checkbox, Checkbox: Open / Done / Cancelled (on a checkbox line)
  mdview = true, -- Preview in mdview (with mdview.nvim, in a buffer that has a file)
  image  = true, -- Paste image (with images.nvim)
}
```

The last two hand the buffer to a sister plugin and appear only when it is
installed: [mdview.nvim](https://github.com/WKDSteve/mdview.nvim) (the same
`:Markdown mdview` runs) and [images.nvim](https://github.com/WKDSteve/images.nvim)
(the same `:Markdown image paste` runs).

`integrations.ui_menu = false` keeps ui.nvim's right-click menu (`ui.menu`)
from showing the fly-out, while `items()`/`submenu()` still work for any other
host; the module also answers `require("markdown.integrations.menu").enabled()`,
which is what `ui.menu` asks first (`false` when either that switch or
`menu.enable` is off).

```lua
integrations = { ui_menu = true }
```

Wire it into your menu dispatcher — get a ready entry list (or a `Markdown ▸`
submenu) and compose it with your own menu:

```lua
local md = require("markdown.integrations.menu")

-- inline entries for the current context (empty table when nothing applies):
local items = md.items()               -- { { name, cmd, rtxt }, … }

-- or a single fly-out entry:
local sub = md.submenu()               -- { name = "Markdown", icon = …, items = {…} } | nil

-- e.g. in a RightMouse handler for markdown buffers:
--   local composed = vim.list_extend(md.items(), require("menus.custom"))
--   require("menu").open(composed, { mouse = true })
```
