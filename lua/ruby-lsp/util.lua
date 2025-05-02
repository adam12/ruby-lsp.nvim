---Utility Helpers

local M = {}

M.buffer = {
  ---Check if a buffer is valid.
  ---@param bufnr integer|nil Buffer number
  ---@return boolean
  is_valid = function(bufnr)
    return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr)
  end,

  ---Sets a buffer to be modifiable.
  ---@param bufnr integer The buffer number to modify.
  make_modifiable = function(bufnr) vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr }) end,

  ---Sets a buffer to be non-modifiable.
  ---@param bufnr integer The buffer number to modify.
  make_nomodifiable = function(bufnr) vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr }) end,

  ---Replace the contents of a buffer with given lines
  ---@param bufnr integer Buffer number
  ---@param lines string[] List of lines to set in the buffer
  reset_contents = function(bufnr, lines) vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines) end,

  ---Asynchronously append lines to a buffer at a given position.
  ---@param bufnr integer Buffer number
  ---@param lines string[] List of lines to append
  ---@param append_pos integer Position to append at
  ---@param on_complete fun()? Optional callback to call after appending
  append = function(bufnr, lines, append_pos, on_complete)
    vim.schedule(function()
      if not (M.buffer.is_valid(bufnr)) then return end
      if type(lines) ~= 'table' or #lines == 0 then return end

      vim.api.nvim_buf_set_lines(bufnr, append_pos, append_pos, false, lines)

      if on_complete then on_complete() end
    end)
  end,

  ---Create a new scratch buffer.
  ---@param name string Name to assign to the buffer
  ---@return integer bufnr Buffer number
  create_scratch = function(name)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value('buftype', 'nofile', { buf = bufnr })
    vim.api.nvim_set_option_value('bufhidden', 'hide', { buf = bufnr })
    vim.api.nvim_buf_set_name(bufnr, name)

    return bufnr
  end,
}

M.window = {
  ---Check if a window is valid.
  ---@param winnr integer|nil Window number
  ---@return boolean
  is_valid = function(winnr) return winnr ~= nil and vim.api.nvim_win_is_valid(winnr) end,

  ---Split the window, load the buffer, set options, and return focus to original window.
  ---@param bufnr integer Buffer number
  ---@param opts table<string, any> Window options to set
  ---@return integer winnr Window number
  split_and_retain_focus = function(bufnr, opts)
    local current_winnr = vim.api.nvim_get_current_win()

    vim.cmd('botright split')
    local winnr = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(winnr, bufnr)
    for opt, value in pairs(opts) do
      vim.api.nvim_set_option_value(opt, value, { win = winnr })
    end

    vim.api.nvim_set_current_win(current_winnr) -- Return focus to original window

    return winnr
  end,
}

---String a string on whitespace
---@param str String A string to split
---@return table result String elements
M.split = function(str)
  local result = {}
  for word in string.gmatch(str, '%S+') do
    table.insert(result, word)
  end
  return result
end

return M
