vim.opt.termguicolors = true
vim.opt.rtp:prepend(".")

-- Setup
require("colorizer").setup({
  user_default_options = {
    css = true,
  },
})

-- Edit file to trigger parsing
vim.cmd("edit test/var_test.css")
vim.cmd("set filetype=css")

-- Wait a bit for async things (if any, though buffer load is sync)
vim.wait(100)

-- Check CSS state
local css = require("colorizer.css")
local bufnr = vim.api.nvim_get_current_buf()
local val = css.get_variable(bufnr, "primary")

if val == "ff0000" then
  print("SUCCESS: primary var found: " .. val)
else
  print("FAILURE: primary var not found or wrong value: " .. tostring(val))
  vim.cmd("cquit 1")
end

local val2 = css.get_variable(bufnr, "tertiary")
-- Recursion is not explicitly handled in my simple implementation yet!
-- Wait, `css.update_variables` calls `color_parser`.
-- `color_parser` (matcher) should handle `var()`.
-- So if `val` is `var(--primary)`, `color_parser` should parse it and return the value of `primary`.
-- Let's see if my implementation handles one level of indirection automatically.

if val2 == "ff0000" then
  print("SUCCESS: tertiary var resolved: " .. val2)
else
  print("INFO: tertiary var raw value: " .. tostring(val2))
end

vim.cmd("quit")
