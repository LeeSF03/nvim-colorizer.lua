vim.opt.termguicolors = true
vim.opt.rtp:prepend(".")

-- Setup with global files
require("colorizer").setup({
  user_default_options = {
    css = true,
    css_var_user_files = { "test/global_vars.css" }
  },
})

-- Edit a dummy file
vim.cmd("edit test/dummy.css")
vim.cmd("set filetype=css")

-- Check CSS state
local css = require("colorizer.css")
local bufnr = vim.api.nvim_get_current_buf()
local val = css.get_variable(bufnr, "global-primary")

if val == "00ff00" then
  print("SUCCESS: global-primary var found: " .. val)
else
  print("FAILURE: global-primary var not found or wrong value: " .. tostring(val))
  vim.cmd("cquit 1")
end

vim.cmd("quit")
