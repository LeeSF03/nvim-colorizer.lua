--[[-- Handles Tailwind CSS color highlighting within buffers.
This module integrates with the Tailwind CSS Language Server Protocol (LSP) to retrieve and apply
color highlights for Tailwind classes in a buffer. It manages LSP attachment, autocmds for color updates,
and maintains state for efficient Tailwind highlighting.
]]
-- @module colorizer.tailwind
local M = {}

local utils = require("colorizer.utils")
local css = require("colorizer.css")
local tw_data = require("colorizer.data.tailwind_colors")
local tw_ns_id = require("colorizer.constants").namespace.tailwind_lsp

local lsp_cache = {}

--- Cleanup tailwind variables and autocmd
---@param bufnr number|nil: buffer number (0 for current)
function M.cleanup(bufnr)
  bufnr = utils.bufme(bufnr)
  if lsp_cache[bufnr] and lsp_cache[bufnr].au_id and lsp_cache[bufnr].au_id[1] then
    for _, au_id in ipairs(lsp_cache[bufnr].au_id) do
      pcall(vim.api.nvim_del_autocmd, au_id)
    end
  end
  vim.api.nvim_buf_clear_namespace(bufnr, tw_ns_id, 0, -1)
  for k, _ in pairs(lsp_cache[bufnr]) do
    lsp_cache[bufnr][k] = nil
  end
end

local function highlight(bufnr, ud_opts, add_highlight)
  if not lsp_cache[bufnr] or not lsp_cache[bufnr].client or not lsp_cache[bufnr].client.request then
    return
  end
  lsp_cache[bufnr].document_params = lsp_cache[bufnr].document_params
    or { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  lsp_cache[bufnr].client.request(
    "textDocument/documentColor",
    lsp_cache[bufnr].document_params,
    function(err, results, _, _)
      if err ~= nil then
        utils.log_message("tailwind.highlight: Error: " .. err)
      end
      if err == nil and results ~= nil then
        local data, line_start, line_end = {}, nil, nil
        for _, result in pairs(results) do
          local cur_line = result.range.start.line
          if line_start then
            if cur_line < line_start then
              line_start = cur_line
            end
          else
            line_start = cur_line
          end
          local end_line = result.range["end"].line
          if line_end then
            if end_line > line_end then
              line_end = end_line
            end
          else
            line_end = end_line
          end
          local r, g, b, a =
            result.color.red or 0,
            result.color.green or 0,
            result.color.blue or 0,
            result.color.alpha or 0
          local rgb_hex = string.format("%02x%02x%02x", r * a * 255, g * a * 255, b * a * 255)
          local first_col = result.range.start.character
          local end_col = result.range["end"].character
          data[cur_line] = data[cur_line] or {}
          table.insert(data[cur_line], { rgb_hex = rgb_hex, range = { first_col, end_col } })
        end
        line_start = line_start or 0
        line_end = line_end and (line_end + 2) or -1

        -- Manual scan for CSS variables (fallback/augmentation)
        local css_vars = css.get_variables(bufnr)
        if css_vars and next(css_vars) then
          local lines = vim.api.nvim_buf_get_lines(bufnr, line_start, line_end, false)
          for i, line in ipairs(lines) do
            local lnum = line_start + i - 1
            for name, hex in pairs(css_vars) do
               -- Strip leading dashes
               local name_no_dash = name:match("^%-*(.+)")
               local targets = {}
               if name_no_dash then
                 table.insert(targets, name_no_dash)
                 local stripped = name_no_dash:match("^color%-(.+)")
                 if stripped then table.insert(targets, stripped) end
               end
               
               for _, target in ipairs(targets) do
                 for _, prefix in ipairs(tw_data.prefixes) do
                   local class = prefix .. "-" .. target
                   -- Simple find, could be improved with word boundary check
                   local s, e = line:find(class, 1, true)
                   while s do
                     data[lnum] = data[lnum] or {}
                     -- Check for overlaps? LSP results take precedence usually, but we merge.
                     -- Convert hex to format without # for consistency with LSP parsing logic above?
                     -- LSP parsing logic: string.format("%02x...", ...).
                     -- hex from css.lua might have # or not.
                     local clean_hex = hex:gsub("^#", "")
                     table.insert(data[lnum], { rgb_hex = clean_hex, range = { s - 1, e } })
                     s, e = line:find(class, e + 1, true)
                   end
                 end
               end
            end
          end
        end

        lsp_cache[bufnr].data = data
        add_highlight(bufnr, tw_ns_id, line_start, line_end, data, ud_opts, { tailwind_lsp = true })
      end
    end
  )
end

--- Highlight buffer using values returned by tailwindcss
---@param bufnr number: Buffer number (0 for current)
---@param ud_opts table: `user_default_options`
---@param buf_local_opts table: Buffer local options
---@param add_highlight function: Function to add highlights
---@param on_detach function: Function to call when LSP is detached
---@param line_start number: Start line
---@param line_end number: End line
---@return boolean|nil
function M.lsp_highlight(
  bufnr,
  ud_opts,
  buf_local_opts,
  add_highlight,
  on_detach,
  line_start,
  line_end
)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  lsp_cache[bufnr] = lsp_cache[bufnr] or {}
  lsp_cache[bufnr].au_id = lsp_cache[bufnr].au_id or {}

  if
    vim.version().minor >= 8 and not lsp_cache[bufnr].client or lsp_cache[bufnr].client.is_stopped()
  then
    -- create the autocmds so tailwind colors only activate when tailwindcss lsp is active
    if not lsp_cache[bufnr].au_created then
      vim.api.nvim_buf_clear_namespace(bufnr, tw_ns_id, 0, -1)
      lsp_cache[bufnr].au_id[1] = vim.api.nvim_create_autocmd("LspAttach", {
        group = buf_local_opts.__augroup_id,
        buffer = bufnr,
        callback = function(args)
          local ok, client = pcall(vim.lsp.get_client_by_id, args.data.client_id)
          if ok and client then
            if
              client.name == "tailwindcss"
              and client.supports_method("textDocument/documentColor", bufnr)
            then
              lsp_cache[bufnr].client = client
              highlight(bufnr, ud_opts, add_highlight)
            end
          end
        end,
      })
      -- make sure the autocmds are deleted after lsp server is closed
      lsp_cache[bufnr].au_id[2] = vim.api.nvim_create_autocmd("LspDetach", {
        group = buf_local_opts.__augroup_id,
        buffer = bufnr,
        callback = function()
          on_detach(bufnr)
        end,
      })
      lsp_cache[bufnr].au_created = true
    end

    vim.api.nvim_buf_clear_namespace(bufnr, tw_ns_id, 0, -1)

    local ok, client = pcall(function()
      local clients = vim.lsp.get_clients({ bufnr = bufnr, name = "tailwindcss" })
      local client = clients[1]
      if client and client:supports_method("textDocument/documentColor", bufnr) then
        return client
      end
    end)
    if not (ok and client) then
      return
    end

    lsp_cache[bufnr].client = client
    highlight(bufnr, ud_opts, add_highlight)

    return true
  end

  if lsp_cache[bufnr].client then
    if
      lsp_cache[bufnr].data
      and not lsp_cache[bufnr].cache_highlighted
      and buf_local_opts.__event == "WinScrolled"
    then
      add_highlight(
        bufnr,
        tw_ns_id,
        line_start,
        line_end,
        lsp_cache[bufnr].data,
        ud_opts,
        { tailwind_lsp = true }
      )
      lsp_cache[bufnr].cache_highlighted = true
    else
      highlight(bufnr, ud_opts, add_highlight)
    end
  end
end

return M
