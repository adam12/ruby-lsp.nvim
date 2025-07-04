--- Ruby LSP Code Lens
-- This module enhances Neovim's code lens capabilities for Ruby LSP by:
-- 1. Filtering supported code lens commands
-- 2. Setting up auto-refresh for code lenses
-- 3. Implementing handlers for Ruby LSP specific commands

local M = {}
local util = require('ruby-lsp.util')

-- Defaults for command output window
local output_state = {
  bufnr = nil,
  winnr = nil,
  append_position = 0,
}
-- local append_position = 0

-- Setup codelens
local supported_commands = {
  ['rubyLsp.runTest'] = true,
  ['rubyLsp.runTask'] = true,
  ['rubyLsp.openFile'] = true,
}
local original_codelens_handler = vim.lsp.codelens.on_codelens

-- Parse test output for quickfix.
-- Equivalent to `setlocal errorformat=%Z,%E%>Failure:,%C%o\ [%f:%l]:,%+C%.%#,%-G%.%#`
local errorformat = table.concat({
  '%Z', -- Consider any blank line to be the end of a multiline message
  '%E%>Failure:', -- "Failure:" Start capturing multiline message
  '%C%o [%f:%l]:', -- Match test name, file and line (module capture seems to be broken?)
  '%+C%.%#', -- Add any line with content to the message (while we are in multiline context)
  '%-G%.%#', -- Ignore any unmatched lines
}, ',')

---Sets up filter for code lenses to only show supported commands
---Overrides the default LSP code lens handler to filter out unsupported commands like 'Debug'
local function setup_lens_filter()
  ---@diagnostic disable-next-line: duplicate-set-field
  vim.lsp.codelens.on_codelens = function(err, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)

    -- Only proceed if we're working with ruby_lsp
    if not client or client.name ~= 'ruby_lsp' then return original_codelens_handler(err, result, ctx) end

    local filtered_result = vim.tbl_filter(
      function(lens) return lens.command and supported_commands[lens.command.command] end,
      result or {}
    )

    return original_codelens_handler(err, filtered_result, ctx)
  end
end

---Creates autocommands to refresh code lenses on various events
local function setup_refresh_autocmd()
  vim.api.nvim_create_autocmd({ 'LspAttach', 'BufEnter', 'CursorHold', 'InsertLeave' }, {
    pattern = { '*.rb', '*.erb' },
    callback = function(args) vim.lsp.codelens.refresh({ bufnr = args.buf }) end,
    desc = 'Refresh active code lenses',
  })
end

---Creates a split window and buffer to display command output
---@param command string Command to run
local function prepare_output_window(command)
  -- Prepare the buffer
  if not util.buffer.is_valid(output_state.bufnr) then
    output_state.bufnr = util.buffer.create_scratch('Command Output: ' .. command)
  end
  util.buffer.make_modifiable(output_state.bufnr)
  util.buffer.reset_contents(output_state.bufnr, { 'Running command: ' .. command, '' })

  -- Prepare the window
  if not util.window.is_valid(output_state.winnr) then
    output_state.winnr = util.window.split_and_retain_focus(output_state.bufnr, {
      number = false,
      relativenumber = false,
    })
  end

  output_state.append_position = 2 -- Current line for appending output (start after the header line)
end

---Cleans up the output window after the command execution
local function cleanup_output_window()
  -- assert(output_bufnr, 'output_bufnr must be set before handling output') -- Help Linter
  util.buffer.make_nomodifiable(output_state.bufnr)
end

---Handles output from a command. Appends the output to the output buffer
---@param output string[] Output data from the command
local function display_command_output(_, output)
  if not output then return end

  util.buffer.append(
    output_state.bufnr,
    output,
    output_state.append_position,
    function() output_state.append_position = output_state.append_position + #output end
  )
end

local function run_command(command, on_stdout, on_stderr, on_exit)
  local job_id = vim.fn.jobstart(command, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = on_stdout,
    on_stderr = on_stderr,
    on_exit = on_exit,
  })

  -- If job failed to start
  if job_id <= 0 then vim.notify('Failed to start command: ' .. command, vim.log.levels.ERROR) end
end

---Launch the test runner command, display output and populate quickfix.
---@param command table Command table from LSP
local function run_test_command(command)
  local command_to_run = command.arguments[3]

  -- Prepare the output window and buffer for displaying command results
  prepare_output_window(command_to_run)
  util.quickfix.clear()

  local on_stdout = function(_, data)
    if data then
      display_command_output(_, data)
      util.quickfix.append(data, 'rails/test', errorformat)
    end
  end

  local on_stderr = function(_, data)
    display_command_output(_, data)
    -- if data and data[1] ~= '' then
    --   vim.notify('Error: ' .. table.concat(data, '\n'), vim.log.levels.WARN)
    -- end
  end

  local on_exit = function(_, _) cleanup_output_window() end

  run_command(command_to_run, on_stdout, on_stderr, on_exit)
end

---Launch the task runner command, used for doing migrations
---@param command table Command table from LSP
---Launch the task runner command for specific tasks like migrations
-- Displays the task command output in a split window for better visibility.
local function run_task_command(command)
  local command_to_run = command.arguments[1]
  prepare_output_window(command_to_run)

  run_command(command_to_run, display_command_output, display_command_output, function() end)
end

---Jump to file support
---Opens file(s) specified in the command arguments
---Shows a selection UI if multiple files are available
---@param command table Command table with arguments
local function open_file_command(command)
  -- command.arguments[1] is a list of one or more file uris
  local uris = command.arguments[1]

  if #uris == 1 then
    util.edit_file(uris[1])
  else
    -- Display a file picker
    vim.ui.select(uris, {
      prompt = 'Select a file to jump to',
      format_item = function(uri)
        -- Only show everything after the last slash, not the full uri
        return uri:match('^.+/(.+)$')
      end,
    }, util.edit_file)
  end
end

---Sets up code lens functionality for Ruby LSP
---1. Sets up filtering for supported code lens commands
---2. Creates autocommands to refresh code lenses
---3. Registers handlers for Ruby LSP specific commands
M.setup_codelens = function()
  setup_lens_filter()
  setup_refresh_autocmd()
  vim.lsp.commands['rubyLsp.runTest'] = run_test_command
  vim.lsp.commands['rubyLsp.runTask'] = run_task_command
  vim.lsp.commands['rubyLsp.openFile'] = open_file_command
  -- Not currenlty supported:
  --   - rubyLsp.debugTest
end

return M
