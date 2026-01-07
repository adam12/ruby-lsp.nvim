local M = {}

-- Configuration
local config = {
  buffer_size = 100, -- Number of log messages to keep
}

-- Ring buffer for storing log messages
local log_buffer = {}
local current_index = 0

-- Add a message to the ring buffer
local function add_log(message)
  current_index = (current_index % config.buffer_size) + 1
  log_buffer[current_index] = message
end

-- Get all logs in chronological order
local function get_logs()
  local result = {}
  local start_idx = (current_index % config.buffer_size) + 1

  -- Add older messages
  for i = start_idx, config.buffer_size do
    if log_buffer[i] then table.insert(result, log_buffer[i]) end
  end

  -- Add newer messages
  for i = 1, current_index do
    if log_buffer[i] then table.insert(result, log_buffer[i]) end
  end

  return result
end

function M.handlers()
  return {
    ['window/logMessage'] = function(_, result, _)
      -- Format the message with timestamp and level
      local levels = { 'ERROR', 'WARN', 'INFO', 'LOG', 'DEBUG' }
      local level = levels[result.type] or 'UNKNOWN'
      local timestamp = os.date('%Y-%m-%d %H:%M:%S')

      -- Handle multi-line messages by splitting and formatting each line
      local message_lines = {}
      for line in result.message:gmatch('[^\r\n]+') do
        table.insert(message_lines, line)
      end

      -- Format the first line with timestamp and level
      local formatted = string.format('[%s] [%s] %s', timestamp, level, message_lines[1] or '')
      add_log(formatted)

      -- Add any additional lines with proper indentation
      for i = 2, #message_lines do
        -- Add to ring buffer
        add_log(string.format('    %s', message_lines[i]))
      end
    end,
  }
end

-- Log the initialize result from the LSP server
function M.log_initialize(result)
  if result.capabilities then
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local caps = {}
    for key, _ in pairs(result.capabilities) do
      table.insert(caps, key)
    end
    table.sort(caps)
    add_log(string.format('[%s] [INIT] Capabilities: %s', timestamp, table.concat(caps, ', ')))
  end
end

-- Show logs in a new window
function M.show_logs()
  -- Create a new buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Get logs and format for display
  local logs = get_logs()
  local lines = {}
  for _, log in ipairs(logs) do
    table.insert(lines, log)
  end

  -- Set buffer content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'log')

  -- Open in a new tab
  vim.api.nvim_command('tabnew')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Set window options
  vim.api.nvim_win_set_option(win, 'wrap', false)

  -- Set buffer name
  vim.api.nvim_buf_set_name(buf, 'Ruby LSP Log')

  return buf
end

return M
