---@module 'markdown.anchor.is_html_extern_anchor_line'
--- Detects markdown/HTML links that point at an external file (not a `#anchor`).
local api = vim.api

---@internal
---@param s string?
---@return string?
local function trim(s)
  if not s then return nil end
  return s:match("^%s*(.-)%s*$")
end

---@internal
---@param uri string?
---@return boolean?
local function looks_like_file_uri(uri)
  if not uri or uri == "" then return false end
  uri = trim(uri)
  if not uri then return nil end
  if uri:match("^#") then return false end
  -- Windows drive-letter absolute path (`C:/…`, `C:\…`), not a URI scheme.
  if uri:match("^%a:[/\\]") then return true end
  if uri:match("^%w[%w+.-]*:") then return false end
  if uri:match("[/\\]") then return true end
  if uri:match("%.[%w%d]+%s*$") then return true end
  if uri:match("%.%w+[#]") or uri:match("%.%w+$") then return true end
  return false
end

---@internal
--- Every markdown link (`[text](target)`, also `![alt](src)`) on `line`, with
--- its 1-based byte span. A bare parenthesis in prose is no link target.
---@param line string
---@return { s: integer, e: integer, target: string }[]
local function md_links(line)
  local links = {}
  local init = 1
  while true do
    local s, e = line:find("%b[]", init)
    if not s then break end
    local ps, pe = line:find("^%b()", e + 1)
    if ps then
      local inner = trim(line:sub(ps + 1, pe - 1))
      if inner and inner ~= "" then links[#links + 1] = { s = s, e = pe, target = inner } end
      init = pe + 1
    else
      init = s + 1
    end
  end
  return links
end

---@internal
--- The markdown link target that counts for `line`: the link under the cursor
--- column `col` (0-based) when there is one -- `false` when that link is no
--- file -- else the first link that points at a file.
---@param line string?
---@param col integer?
---@return string|false|nil
local function extract_md_paren_target(line, col)
  if not line then return nil end
  local links = md_links(line)
  if col then
    for _, lk in ipairs(links) do
      if col + 1 >= lk.s and col + 1 <= lk.e then
        return looks_like_file_uri(lk.target) and lk.target or false
      end
    end
  end
  for _, lk in ipairs(links) do
    if looks_like_file_uri(lk.target) then return lk.target end
  end
  return nil
end

---@internal
---@param line string?
---@return string?
local function extract_html_attr(line)
  if not line then return nil end
  local href = line:match('<a[^>]-href%s*=%s*"(.-)"') or line:match("<a[^>]-href%s*=%s*'(.-)'")
  if href and href ~= "" then return href end
  href = line:match('<img[^>]-src%s*=%s*"(.-)"') or line:match("<img[^>]-src%s*=%s*'(.-)'")
  if href and href ~= "" then return href end
  href = line:match("<a[^>]-href%s*=%s*([^%s>]+)") or line:match("<img[^>]-src%s*=%s*([^%s>]+)")
  if href and href ~= "" then return href end
  return nil
end

---@internal
---@param radius integer? Line radius to scan around the cursor (default 8).
---@return string?
local function find_attr_near_cursor(radius)
  radius = radius or 8
  local ok, bufnr = pcall(api.nvim_get_current_buf)
  if not ok or not bufnr then return nil end
  local ok2, cur = pcall(api.nvim_win_get_cursor, 0)
  local curline = (ok2 and cur and cur[1]) or 1
  local start_line = math.max(1, curline - radius)
  local end_line = math.min(api.nvim_buf_line_count(bufnr), curline + radius)
  local ok3, lines = pcall(api.nvim_buf_get_lines, bufnr, start_line - 1, end_line, false)
  if not ok3 or not lines then return nil end
  local joined = table.concat(lines, " ")
  local v = joined:match('href%s*=%s*"(.-)"')
    or joined:match("href%s*=%s*'(.-)'")
    or joined:match('src%s*=%s*"(.-)"')
    or joined:match("src%s*=%s*'(.-)'")
  if v and v ~= "" then return trim(v) end
  return nil
end

---@internal
---@param s string?
---@return string? target
---@return string? fragment
local function parse_href_target(s)
  if not s or s == "" then return nil end
  if s:match("^<.+>$") then s = s:sub(2, -2) end
  s = trim(s)
  if not s then return nil end
  local token = s:match("^(%S+)") or s
  local before, frag = token:match("^(.-)#(.-)$")
  if before then return trim(before), trim(frag) end
  return token, nil
end

---@param line string? Current line under the cursor, if any.
---@param col integer? 0-based cursor column on `line`; a link under it decides.
---@return { target: string, fragment: string? }?
return function(line, col)
  if not line or line == "" then
    local near = find_attr_near_cursor(8)
    if near and looks_like_file_uri(near) then
      local t, f = parse_href_target(near)
      if t then return { target = t, fragment = f } end
    end
    return nil
  end

  local md_target = extract_md_paren_target(line, col)
  -- The cursor sits on a markdown link that is no file (a URL, `#anchor`):
  -- that link decides, the cursor-aware link resolution of the handler opens it.
  if md_target == false then return nil end
  if md_target then
    local t, f = parse_href_target(md_target)
    if t then return { target = t, fragment = f } end
  end

  local html_target = extract_html_attr(line)
  if html_target and looks_like_file_uri(html_target) then
    local t, f = parse_href_target(html_target)
    if t then return { target = t, fragment = f } end
  end

  -- The near-cursor scan is for multi-line HTML blocks; a line with markdown
  -- links of its own is left to the handler's cursor-aware link resolution,
  -- so a `src=` on a neighbouring line cannot claim it.
  if #md_links(line) > 0 then return nil end
  local near = find_attr_near_cursor(12)
  if near and looks_like_file_uri(near) then
    local t, f = parse_href_target(near)
    if t then return { target = t, fragment = f } end
  end

  return nil
end
