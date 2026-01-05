--[[-- This module provides a parser for identifying and converting CSS `var()` functions.
It looks up the variable name in the buffer's CSS variable definitions.
]]
-- @module colorizer.parser.css_var
local M = {}

local css = require("colorizer.css")

--- Parses `var()` CSS functions.
---@param line string: The line of text to parse
---@param i number: The starting index
---@param opts table: Parsing options (unused)
---@param bufnr number: Buffer number (required for lookup)
---@return number|nil: The end index of the match
---@return string|nil: The RGB hexadecimal color
function M.parser(line, i, opts, bufnr)
  -- Match var(--name) or var(--name, fallback)
  local start_match, end_match, name = line:find("^var%s*%(%s*%-%-([%w%-]+)[^)]*%)", i)
  
  if not start_match then
    return
  end

  if not bufnr then
    return
  end

  local rgb_hex = css.get_variable(bufnr, name)
  if rgb_hex then
    return end_match, rgb_hex
  end
  
  -- TODO: Parse fallback value if variable is missing?
  -- Regex above captures name but ignores fallback content.
end

return M
