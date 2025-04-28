--- Ruby LSP Code Lens
-- This module enhances Neovim's code lens capabilities for Ruby LSP by:
-- 1. Filtering supported code lens commands
-- 2. Setting up auto-refresh for code lenses
-- 3. Implementing handlers for Ruby LSP specific commands

local M = {}

local original_codelens_handler = vim.lsp.codelens.on_codelens
local supported_commands = {
  ['rubyLsp.runTest'] = true,
  ['rubyLsp.runTask'] = true,
  ['rubyLsp.openFile'] = true,
}

-- Override the default lens handler.
-- This allows us to filter unsupported command, like "Debug"
local function setup_lens_filters()
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

local function setup_refresh_autocmd()
  vim.api.nvim_create_autocmd({ 'LspAttach', 'BufEnter', 'CursorHold', 'InsertLeave' }, {
    pattern = { '*.rb', '*.erb' },
    callback = function(args) vim.lsp.codelens.refresh({ bufnr = args.buf }) end,
    desc = 'Refresh active code lenses',
  })
end

-- This is used as a callback when handling openFile commands.
-- Edit the given file. Handles line numbers in the URI
-- URIs are in the forms:
--   file:///path/to/file.rb
--   file:///path/to/file.rb#L99
-- We strip the protocol and line numbers from the path
local function edit_file(uri, _)
  -- If the file picker is cancelled, the callback still runs
  if not uri then return end

  local line = tonumber(uri:match('#L(%d+)') or 1) -- Extract the line number, default to 1
  local path = uri:gsub('^file://', ''):gsub('#L%d+', '') -- Remove the protocol and line number

  vim.cmd(string.format('edit +%d %s', line, path))
end

-- Launch the test runner command
local function run_test_command(command) vim.cmd(':split | terminal ' .. command.arguments[3]) end

-- Launch the task runner command, used for doing migrations
local function run_task_command(command) vim.cmd(':split | terminal ' .. command.arguments[1]) end

-- Jump to file support
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

M.setup_codelens = function()
  setup_lens_filters()
  setup_refresh_autocmd()
  vim.lsp.commands['rubyLsp.runTest'] = run_test_command
  vim.lsp.commands['rubyLsp.runTask'] = run_task_command
  vim.lsp.commands['rubyLsp.openFile'] = open_file_command
  -- Not currenlty supported:
  --   - rubyLsp.runTestInTerminal
  --   - rubyLsp.debugTest
end

return M
