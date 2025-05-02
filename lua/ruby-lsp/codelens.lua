--- Ruby LSP Code Lens
-- This module enhances Neovim's code lens capabilities for Ruby LSP by:
-- 1. Filtering supported code lens commands
-- 2. Setting up auto-refresh for code lenses
-- 3. Implementing handlers for Ruby LSP specific commands

local M = {}
local util = require('ruby-lsp.util')

local output_bufnr = nil
local output_winnr = nil
local append_position = 0

---Handles command response from jobstart
---Appends the output to the output buffer
---@param _ integer Ignored channel id
---@param output string[] Output data from the command
local function display_command_output(_, output)
  if not output then return end
  assert(output_bufnr, 'output_bufnr must be set before handling output') -- Help linter

  util.buffer.append(output_bufnr, output, append_position, function() append_position = append_position + #output end)
end

---Creates a split window to display command output
---Sets up the buffer and window for displaying command output, then runs the command asynchronously
---@param command string Command to run
local function run_command_in_split(command)
  -- Prepare the buffer
  if not util.buffer.is_valid(output_bufnr) then
    output_bufnr = util.buffer.create_scratch('Command Output: ' .. command)
  end
  assert(output_bufnr, 'output_bufnr must be set before handling output') -- Help Linter
  util.buffer.make_modifiable(output_bufnr)
  util.buffer.reset_contents(output_bufnr, { 'Running command: ' .. command, '' })

  -- Prepare the window
  if not util.window.is_valid(output_winnr) then
    output_winnr = util.window.split_and_retain_focus(output_bufnr, {
      number = false,
      relativenumber = false,
    })
  end

  append_position = 2 -- Current line for appending output (start after the header line)

  -- Run the command asynchronously
  local job_id = vim.fn.jobstart(command, {
    on_stdout = display_command_output,
    on_stderr = display_command_output,
    on_exit = function() util.buffer.make_nomodifiable(output_bufnr) end,
    stdout_buffered = false,
    stderr_buffered = false,
  })

  -- If job failed to start
  if job_id <= 0 then vim.notify('Failed to start command: ' .. command, vim.log.levels.ERROR) end
end

local original_codelens_handler = vim.lsp.codelens.on_codelens
local supported_commands = {
  ['rubyLsp.runTest'] = true,
  ['rubyLsp.runTask'] = true,
  ['rubyLsp.openFile'] = true,
  ['rubyLsp.debugTest'] = true,
}

---Sets up filters for code lenses to only show supported commands
---Overrides the default LSP code lens handler to filter out unsupported commands like 'Debug'
local function setup_lens_filters()
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

---This is used as a callback when handling openFile commands.
---Edit the given file. Handles line numbers in the URI
---URIs are in the forms:
---  file:///path/to/file.rb
---  file:///path/to/file.rb#L99
---We strip the protocol and line numbers from the path
---@param uri string File URI in format 'file:///path/to/file.rb' or 'file:///path/to/file.rb#L99'
---@param _ any Ignored callback context parameter
local function edit_file(uri, _)
  -- If the file picker is cancelled, the callback still runs
  if not uri then return end

  local line = tonumber(uri:match('#L(%d+)') or 1) -- Extract the line number, default to 1
  local path = uri:gsub('^file://', ''):gsub('#L%d+', '') -- Remove the protocol and line number

  vim.cmd(string.format('edit +%d %s', line, path))
end

---Launch the test runner command
---@param command table Command table from LSP
local function run_test_command(command)
  --Display test command output in a split window
  run_command_in_split(command.arguments[3])
end

---Launch the task runner command, used for doing migrations
---@param command table Command table from LSP
local function run_task_command(command)
  -- Display task command output in a split window
  run_command_in_split(command.arguments[1])
end

---Jump to file support
---Opens file(s) specified in the command arguments
---Shows a selection UI if multiple files are available
---@param command table Command table with arguments
local function open_file_command(command)
  -- command.arguments[1] is a list of one or more file uris
  local uris = command.arguments[1]

  if #uris == 1 then
    edit_file(uris[1])
  else
    -- Display a file picker
    vim.ui.select(command.arguments[1], {
      prompt = 'Select a file to jump to',
      format_item = function(uri)
        -- Only show everything after the last slash, not the full uri
        return uri:match('^.+/(.+)$')
      end,
    }, edit_file)
  end
end

local function setup_dap()
  M._dap.adapters.ruby_lsp = function(on_config, config)
    on_config({
      type = 'pipe',
      pipe = '${pipe}',
      executable = {
        command = 'bundle',
        args = {
          'exec',
          'rdbg',
          '--no-color',
          '--open',
          '--sock-path=${pipe}',
          '--',
          unpack(config.args or {}),
        },
      },
    })
  end
end

---Debug the current test file or individual test
---@param command table Command table from LSP
local function debug_command(command)
  -- This is in the form "/path/to/ruby bin/rails test /path/to/test.rb:line_number"
  local program_args = util.split(command.arguments[3])
  -- We want to drop the "path/to/ruby"
  table.remove(program_args, 1)

  M._dap.run({
    type = 'ruby_lsp',
    name = 'Debug test',
    request = 'launch',
    args = program_args,
  })
end

---Sets up code lens functionality for Ruby LSP
---1. Sets up filtering for supported code lens commands
---2. Creates autocommands to refresh code lenses
---3. Registers handlers for Ruby LSP specific commands
M.setup_codelens = function()
  setup_lens_filters()
  setup_refresh_autocmd()
  vim.lsp.commands['rubyLsp.runTest'] = run_test_command
  vim.lsp.commands['rubyLsp.runTask'] = run_task_command
  vim.lsp.commands['rubyLsp.openFile'] = open_file_command

  local ok, dap = pcall(require, 'dap')
  if ok then
    M._dap = dap
    setup_dap()
    vim.lsp.commands['rubyLsp.debugTest'] = debug_command
  end

  -- Not currenlty supported:
  --   - rubyLsp.runTestInTerminal
  --   - rubyLsp.debugTest
end

return M
