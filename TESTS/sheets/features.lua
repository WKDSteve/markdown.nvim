-- TESTS/sheets/features.lua -- the functionalities of markdown.nvim as its user meets them; `testing sheets report`
-- says which ones have a feature sheet (`feature = "<id>"`) and in which state, and K16 warns about a sheet that names
-- an id not listed here. Data: read with an empty environment like a sheet (testing.nvim docs/SHEETS.md).
-- The list follows docs/FEATURES/ (README.md and its seven pages).
local H = "docs/FEATURES/HEADINGS.md"
local E = "docs/FEATURES/EDITING-AND-HANDLERS.md"
local L = "docs/FEATURES/LINKS-AND-REFERENCES.md"
local T = "docs/FEATURES/TABLES.md"
local U = "docs/FEATURES/HIGHLIGHTING-AND-UI.md"
local I = "docs/FEATURES/INTEGRATIONS.md"
return {
  -- Rendering
  {
    id = "markdown.render",
    title = "Markdown renders in the buffer itself, also in folded regions and while typing in insert mode",
    docs = I,
  },
  -- Headings
  {
    id = "markdown.heading-nav",
    title = "Move to the previous or next heading or fenced-code delimiter",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.heading-shift",
    title = "Raise or lower the level of a heading, a range or the whole buffer",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.heading-format",
    title = "Normalize the text of a heading without touching its level",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.folding",
    title = "Headings (ATX and Setext) fold through the plugin's foldexpr",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.toc",
    title = "Insert or refresh a table of contents with GFM anchors",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.headline-spacing",
    title = "A blank --- blank separator between consecutive sections",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  {
    id = "markdown.setext-underline",
    title = "A line of = below every heading, matching its width",
    perf = "skip:no process: buffer text and files only",
    docs = H,
  },
  -- Editing
  {
    id = "markdown.format",
    title = ":Markdown format applies its formatting ops to a buffer, a file or a tree",
    perf = "skip:no process: buffer text and files only",
    docs = E,
  },
  {
    id = "markdown.bold-wrap",
    title = "Toggle **bold** on a visual selection",
    perf = "skip:no process: buffer text and files only",
    docs = E,
  },
  {
    id = "markdown.cursor-action",
    title = "One key acts on what is under the cursor: anchors jump, links open",
    docs = E,
  },
  {
    id = "markdown.image-paste",
    title = "Paste a clipboard image or a screenshot as a file and a link",
    perf = "skip:no process of its own: delegates to images.nvim (:Image paste/screenshot), which starts the clipboard tools",
    docs = E,
  },
  {
    id = "markdown.checkboxes",
    title = "A list checkbox steps through open, done and cancelled",
    perf = "skip:no process: buffer text and files only",
    docs = E,
  },
  -- Links and references
  {
    id = "markdown.link-wrap",
    title = "Wrap the word under the cursor or a selection in a Markdown link",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.links-show",
    title = "Every link of the buffer in a picker, opened as URL, file or anchor",
    docs = L,
  },
  {
    id = "markdown.link-diagnostics",
    title = "Dead relative links and duplicate anchors are diagnostics",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.link-sanitize",
    title = "Inline-link targets are normalized (slashes, bare paths)",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.refs",
    title = "Anchor links and the TOC stay consistent when a heading is renamed",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.anchor-jump",
    title = "Jump to a #heading anchor by its GFM slug",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.links-create",
    title = "Create the files and folders the link targets of a range name",
    perf = "skip:no process: buffer text and files only",
    docs = L,
  },
  {
    id = "markdown.link-delete",
    title = "DD on a link to an existing file offers to delete the file too",
    docs = L,
  },
  -- Tables
  {
    id = "markdown.table-format",
    title = "Pipe tables are parsed and re-rendered aligned (GFM formatter)",
    perf = "skip:no process: buffer text and files only",
    docs = T,
  },
  {
    id = "markdown.table-mode",
    title = "Table mode formats the table live while typing",
    perf = "skip:no process: buffer text and files only",
    docs = T,
  },
  {
    id = "markdown.tableview",
    title = "A floating table preview, aligned or box-drawn, and its export",
    docs = T,
  },
  {
    id = "markdown.table-wrap",
    title = "Tables wrap to a width cap (:MDTable*)",
    perf = "skip:no process: buffer text and files only",
    docs = T,
  },
  {
    id = "markdown.table-list",
    title = ":Markdown table list shows the tables of a scope in a picker with a preview; choosing one jumps there",
    surface = { "command:Markdown table list" },
    docs = T,
  },
  {
    id = "markdown.table-formats",
    title = "Tables beyond GFM are read through one registry",
    perf = "skip:no process: buffer text and files only",
    docs = T,
  },
  {
    id = "markdown.table-render",
    title = "Every table is drawn as a grid that fits its window, also in two windows of different width",
    docs = T,
  },
  {
    id = "markdown.table-truncate",
    title = "A table keeps one row per line, cut cells show their full text in a popup",
    docs = T,
  },
  -- Highlighting
  {
    id = "markdown.highlighting",
    title = "Code, blockquotes and inline links get their own highlights",
    perf = "skip:no process: buffer text and files only",
    docs = U,
  },
  -- Integrations
  {
    id = "markdown.preview",
    title = "A browser preview of the buffer through mdview.nvim",
    perf = "skip:no process of its own: delegates to mdview.nvim, which starts its server and the browser",
    docs = I,
  },
  {
    id = "markdown.pdf",
    title = "Follow a .pdf link or export the buffer through pdfport.nvim",
    perf = "skip:no process of its own: pdfport.nvim exports (pandoc) and shows; a .pdf opened in the system app is the opener of handler.cursor-action-system-opener",
    docs = I,
  },
}
