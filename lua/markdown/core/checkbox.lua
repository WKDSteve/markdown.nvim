---@module 'markdown.core.checkbox'
---@brief Task-list checkboxes: find the box of a line and step its state.
---@description
--- A box is `[<state>]` right after a list marker (`-`, `*`, `+`, `1.`, `1)`),
--- at any indent and inside block quotes, followed by whitespace or the end of
--- the line. `- [x](url)` is a link and `- [a] text` is plain text: a state has
--- to be one of the configured states or one the renderer knows.
---
--- Only the state character is ever rewritten (`nvim_buf_set_text`), so the
--- indent, the marker, the text after the box and a trailing `\r` stay as they
--- were, and the cursor does not move. A box inside a fenced code block is an
--- example, not a task, and is left alone.

local M = {}

local api = vim.api

---@type string[]
local DEFAULT_STATES = { " ", "x", "~" }

---Whether a string is one UTF-8 character that may sit between the brackets.
---@param s any
---@return boolean
local function is_state(s)
  return type(s) == "string"
    and s ~= "]"
    and s ~= "["
    and s:match("^[%z\1-\127\194-\244][\128-\191]*$") ~= nil
end

---The configured cycle. A wrong value falls back to the default rather than
---leaving the keys without an effect.
---@return string[]
function M.states()
  local cfg = require("markdown.config").get()
  local states = (cfg.checkbox or {}).states
  if type(states) ~= "table" or #states == 0 then return DEFAULT_STATES end
  for _, s in ipairs(states) do
    if not is_state(s) then return DEFAULT_STATES end
  end
  return states
end

---Whether `state` counts as a checkbox state.
---@param state string
---@return boolean
local function known(state)
  if state == " " or state == "x" or state == "X" or state == "-" or state == "~" then
    return true
  end
  return vim.tbl_contains(M.states(), state)
end

---The box of one line of text.
---@param line string
---@return { state: string, box_col: integer, box_end: integer, state_col: integer }|nil # 0-based columns, `box_end` exclusive
function M.parse(line)
  local after_quote = #line:match("^[%s>]*") + 1
  local box_pos = line:match("^[-*+]%s+()", after_quote) or line:match("^%d+[.)]%s+()", after_quote)
  if not box_pos then return nil end
  local state, close = line:match("^%[([%z\1-\127\194-\244][\128-\191]*)%]()", box_pos)
  if not state or not known(state) then return nil end
  local next_char = line:sub(close, close)
  if next_char ~= "" and not next_char:match("%s") then return nil end
  return { state = state, box_col = box_pos - 1, box_end = close - 1, state_col = box_pos }
end

---Whether row `row` (1-based) lies inside a fenced code block.
---@param bufnr integer
---@param row integer
---@return boolean
local function in_fence(bufnr, row)
  ---@type string|nil
  local open_char
  local open_len = 0
  for _, line in ipairs(api.nvim_buf_get_lines(bufnr, 0, row - 1, false)) do
    local run = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if run then
      if not open_char then
        open_char, open_len = run:sub(1, 1), #run
      elseif run:sub(1, 1) == open_char and #run >= open_len and line:match("^%s*[`~]+%s*$") then
        open_char = nil
      end
    end
  end
  return open_char ~= nil
end

---The box of a buffer row, nil on a row without one.
---@param bufnr? integer
---@param row? integer 1-based, default the cursor row
---@return { state: string, box_col: integer, box_end: integer, state_col: integer }|nil
function M.at(bufnr, row)
  bufnr = bufnr or api.nvim_get_current_buf()
  row = row or api.nvim_win_get_cursor(0)[1]
  local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then return nil end
  local box = M.parse(line)
  if not box or in_fence(bufnr, row) then return nil end
  return box
end

---The state after `state` in the cycle. `X` counts as `x`; a state outside the
---cycle (such as `-`, which the renderer draws as partial) starts it over.
---@param state string
---@return string
function M.next_state(state)
  local states = M.states()
  for i, s in ipairs(states) do
    if s == state or (state == "X" and s == "x") then return states[i % #states + 1] end
  end
  return states[1]
end

---Write `state` into the box of a row.
---@param state string
---@param bufnr? integer
---@param row? integer 1-based, default the cursor row
---@return boolean written # false on a row without a box or in a read-only buffer
function M.set(state, bufnr, row)
  bufnr = bufnr or api.nvim_get_current_buf()
  row = row or api.nvim_win_get_cursor(0)[1]
  local box = M.at(bufnr, row)
  if not box or not vim.bo[bufnr].modifiable then return false end
  if box.state == state then return true end
  api.nvim_buf_set_text(
    bufnr,
    row - 1,
    box.state_col,
    row - 1,
    box.state_col + #box.state,
    { state }
  )
  return true
end

---Step the box of a row to its next state. A row without one is a no-op.
---@param bufnr? integer
---@param row? integer 1-based, default the cursor row
---@return boolean stepped
function M.cycle(bufnr, row)
  bufnr = bufnr or api.nvim_get_current_buf()
  row = row or api.nvim_win_get_cursor(0)[1]
  local box = M.at(bufnr, row)
  if not box then return false end
  return M.set(M.next_state(box.state), bufnr, row)
end

---Whether the cursor stands on the box itself (the brackets and the state), the
---only place a double-click means the box.
---@return boolean
function M.cursor_on_box()
  local pos = api.nvim_win_get_cursor(0)
  local box = M.at(api.nvim_get_current_buf(), pos[1])
  return box ~= nil and pos[2] >= box.box_col and pos[2] < box.box_end
end

return M
