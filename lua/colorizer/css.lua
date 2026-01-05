--[[-- Manages CSS variable parsing and storage.
This module handles the extraction and storage of CSS variables (e.g., --primary: #000;)
from the buffer, allowing them to be referenced by the `var()` parser.
]]
-- @module colorizer.css
local M = {}

local state = {}
local global_definitions = {}

--- Cleanup css variables
---@param bufnr number
function M.cleanup(bufnr)
  state[bufnr] = nil
end

--- Get a variable value
---@param bufnr number
---@param name string
---@return string|nil: The hex color value
function M.get_variable(bufnr, name)
  if state[bufnr] and state[bufnr].definitions and state[bufnr].definitions[name] then
    return state[bufnr].definitions[name]
  end
  return global_definitions[name]
end

--- Load global CSS variables from files
---@param patterns table: List of glob patterns
---@param color_parser function: Parser function
function M.load_global_variables(patterns, color_parser)
  if not patterns or #patterns == 0 then
    return
  end
  global_definitions = {}
  for _, pattern in ipairs(patterns) do
    local files = vim.fn.glob(pattern, true, true)
    for _, file in ipairs(files) do
      local lines = {}
      for line in io.lines(file) do
        table.insert(lines, line)
      end
      -- Parse lines and update global definitions
      -- We pass a dummy bufnr=0 but we are updating global_definitions directly below
      -- Actually, update_variables stores in state[bufnr].
      -- We should extract the parsing logic or just parse here.
      for _, line in ipairs(lines) do
        for name, value in line:gmatch("%-%-([%w%-]+)%s*:%s*(.-)%s*[;}]") do
          if color_parser then
             -- Use 1 as bufnr for context if needed, but hex parser ignores it
            local len, rgb_hex = color_parser(value, 1, 0)
            if len and rgb_hex then
              global_definitions[name] = rgb_hex
            end
          end
        end
      end
    end
  end
end

--- Update CSS variables from the buffer
---@param bufnr number: Buffer number
---@param line_start number
---@param line_end number
---@param lines table|nil
---@param color_parser function|boolean
---@param ud_opts table: `user_default_options`
---@param buf_local_opts table|nil: Buffer local options
function M.update_variables(
  bufnr,
  line_start,
  line_end,
  lines,
  color_parser,
  ud_opts,
  buf_local_opts
)
  lines = lines or vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)

  if not state[bufnr] then
    state[bufnr] = {
      definitions = {},
    }
  end

  -- Reuse existing definitions if not parsing the whole buffer?
  -- For simplicity, we might want to re-parse lazily or incrementally.
  -- But `buffer.lua` usually calls this with `0, -1` when it calls SASS update (on change).
  -- So we can likely just clear and rebuild or update.
  -- Let's stick to simple full-buffer scan or line-range update.
  -- If `lines` corresponds to the whole buffer, we can clear.
  -- If it's a partial update, we should merge.
  -- However, `buffer.lua` seems to call `sass.update_variables` with `0, -1` on events.
  
  -- Let's assume we are building `definitions` for the range provided.
  -- If we want to support incremental updates, we need a more complex state (like sass.lua).
  -- Given "Raw Speed" goal, let's try to be efficient.
  -- But for now, let's implement a simple version that updates definitions found in `lines`.
  
  -- If we are parsing the whole file (0 to -1), clear definitions.
  if line_start == 0 and line_end == -1 then
    state[bufnr].definitions = {}
  end

  for _, line in ipairs(lines) do
    -- Match --name: value;
    -- Value can be complex, but we only care if it starts with a color or is a color.
    -- We use `color_parser` to check if the value is a color.
    for name, value in line:gmatch("%-%-([%w%-]+)%s*:%s*(.-)%s*[;}]") do
      if color_parser then
        -- We try to parse the value using the configured color parser
        -- This handles hex, rgb(), etc.
        local len, rgb_hex = color_parser(value, 1, bufnr)
        if len and rgb_hex then
          state[bufnr].definitions[name] = rgb_hex
        end
      end
    end
  end
end

return M
