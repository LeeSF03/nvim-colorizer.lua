--[[-- Manages CSS variable parsing and storage.
This module handles the extraction and storage of CSS variables (e.g., --primary: #000;)
from the buffer, allowing them to be referenced by the `var()` parser.
]]
-- @module colorizer.css
local M = {}

local utils = require("colorizer.utils")

local state = {}
local global_definitions = {}

--- Get all variables and their hash
---@param bufnr number
---@return table: Variables table
---@return string: Hash of variables
function M.get_variables(bufnr)
  -- Use cached result if available
  if state[bufnr] and state[bufnr].cached_vars and state[bufnr].cached_hash then
    return state[bufnr].cached_vars, state[bufnr].cached_hash
  end

  local vars = {}
  -- Merge global
  for k, v in pairs(global_definitions) do
    vars[k] = v
  end
  -- Merge local
  if state[bufnr] and state[bufnr].definitions then
    for k, v in pairs(state[bufnr].definitions) do
      vars[k] = v
    end
  end

  local hash = utils.hash_table(vars)

  if state[bufnr] then
    state[bufnr].cached_vars = vars
    state[bufnr].cached_hash = hash
  end

  return vars, hash
end

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
  
  -- Invalidate hash and cache
  state[bufnr].hash = nil
  state[bufnr].cached_vars = nil
  state[bufnr].cached_hash = nil

  local pending = {}
  local changed = false

  -- Pass 1: Parse variables, resolving immediate values and collecting deferred ones
  for _, line in ipairs(lines) do
    for name, value in line:gmatch("%-%-([%w%-]+)%s*:%s*(.-)%s*[;}]") do
      if color_parser then
        local len, rgb_hex = color_parser(value, 1, bufnr)
        if len and rgb_hex then
          state[bufnr].definitions[name] = rgb_hex
          changed = true
        else
          -- If not resolved immediately (e.g. forward ref), store for next pass
          table.insert(pending, { name = name, value = value })
        end
      end
    end
  end

  -- Pass 2: Try to resolve deferred variables
  -- We repeat this until no new variables are resolved (to handle chains), up to a limit
  if #pending > 0 and changed then
    local max_passes = 3
    local pass = 0
    while pass < max_passes and changed do
      changed = false
      local next_pending = {}
      for _, entry in ipairs(pending) do
         local len, rgb_hex = color_parser(entry.value, 1, bufnr)
         if len and rgb_hex then
           state[bufnr].definitions[entry.name] = rgb_hex
           changed = true
         else
           table.insert(next_pending, entry)
         end
      end
      pending = next_pending
      pass = pass + 1
    end
  end
end

return M
