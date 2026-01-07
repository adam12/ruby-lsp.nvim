local ruby_lsp = {}
local Job = require('plenary.job')

local logger = require('ruby-lsp/logger')

local function rmdir(dir)
  local handle = vim.loop.fs_scandir(dir)
  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then break end

      local path = dir .. '/' .. name
      if type == 'directory' then
        rmdir(path)
      else
        vim.loop.fs_unlink(path)
      end
    end
    vim.loop.fs_rmdir(dir)
  end
end

local function configure_lspconfig(config)
  local lspconfig = require('lspconfig')

  config.handlers = logger.handlers()

  lspconfig.ruby_lsp.setup(config)
end

local function update_ruby_lsp(callback)
  vim.notify('Updating ruby-lsp...')

  Job:new({
    command = 'gem',
    args = { 'update', 'ruby-lsp' },
    on_exit = function(_j, return_val)
      if return_val == 0 then
        vim.schedule(function()
          vim.notify('Update of ruby-lsp complete!')

          if callback then callback() end
        end)
      else
        vim.schedule(function() vim.notify('Update of ruby-lsp failed!') end)
      end
    end,
  }):start()
end

local function is_ruby_lsp_installed() return vim.fn.executable('ruby-lsp') == 1 end

local function is_standard() return vim.fn.filereadable('.standard.yml') == 1 end

local function is_rubocop() return vim.fn.filereadable('.rubocop.yml') == 1 end

local function create_autocmds(client, buffer)
  -- Implementation from https://github.com/semanticart
  vim.api.nvim_buf_create_user_command(buffer, 'RubyDeps', function(opts)
    local params = vim.lsp.util.make_text_document_params()
    local showAll = opts.args == 'all'

    client.request('rubyLsp/workspace/dependencies', params, function(error, result)
      if error then
        print('Error showing deps: ' .. error)
        return
      end

      local qf_list = {}
      for _, item in ipairs(result) do
        if showAll or item.dependency then
          table.insert(qf_list, {
            text = string.format('%s (%s) - %s', item.name, item.version, item.dependency),
            filename = item.path,
          })
        end
      end

      vim.fn.setqflist(qf_list)
      vim.cmd('copen')
    end, buffer)
  end, { nargs = '?', complete = function() return { 'all' } end })

  vim.api.nvim_create_user_command('RubyLspLog', function() logger.show_logs() end, {})
end

local function install_ruby_lsp(callback)
  vim.notify('Installing ruby-lsp...')

  Job:new({
    command = 'gem',
    args = { 'install', 'ruby-lsp' },
    on_exit = function(_j, return_val)
      if return_val == 0 then
        vim.schedule(function()
          vim.notify('Installation of ruby-lsp complete!')

          if callback then callback() end
        end)
      else
        vim.schedule(function() vim.notify('Installation of ruby-lsp failed!') end)
      end
    end,
    on_stderr = function(_, msg)
      vim.schedule(function() vim.notify(msg) end)
    end,
  }):start()
end

local function detect_tool()
  if is_standard() then return 'standard' end

  if is_rubocop() then return 'rubocop' end
end

ruby_lsp.config = {
  auto_install = true,
  use_launcher = false, -- Use experimental launcher
  autodetect_tools = false, -- Autodetect the formatting and linting tools
  lspconfig = {
    mason = false, -- Prevent LazyVim from installing via Mason
    on_attach = function(client, buffer) create_autocmds(client, buffer) end,
    on_init = function(_, initialize_result) logger.log_initialize(initialize_result) end,
  },
}

ruby_lsp.setup = function(config)
  ruby_lsp.options = vim.tbl_deep_extend('force', {}, ruby_lsp.config, config or {})

  local lspconfig = require('lspconfig')
  lspconfig.util.on_setup = lspconfig.util.add_hook_before(lspconfig.util.on_setup, function(c)
    if c.name == 'ruby_lsp' then
      -- Set a reasonable default if one isn't present
      if c.cmd == nil then c.cmd = { 'ruby-lsp' } end

      if ruby_lsp.options.use_launcher then table.insert(c.cmd, '--use-launcher') end

      if ruby_lsp.options.autodetect_tools then
        local tool = detect_tool()

        if tool then
          c.init_options = vim.tbl_extend('force', c.init_options or {}, {
            formatter = tool,
            linters = { tool },
          })
        end
      end
    end
  end)

  local server_started = false

  -- Autocommand to only install ruby-lsp server when opening a Ruby file
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'ruby', 'eruby' },
    callback = function()
      if not server_started then
        -- This should only be necessary once per vim session
        server_started = true

        if not is_ruby_lsp_installed() and ruby_lsp.options.auto_install then
          install_ruby_lsp(function()
            configure_lspconfig(ruby_lsp.options.lspconfig)
            -- Start the ruby lsp now that it's been configured
            vim.cmd('LspStart ruby_lsp')
          end)
        else
          configure_lspconfig(ruby_lsp.options.lspconfig)
          -- Start the ruby lsp now that it's been configured
          vim.cmd('LspStart ruby_lsp')
        end
      end
    end,
    once = true,
  })

  -- Autocommand to update ruby-lsp
  vim.api.nvim_create_user_command('RubyLspUpdate', function()
    -- Check if ruby_lsp is running to prevent error when stopping non-existant server
    if #vim.lsp.get_clients({ name = 'ruby_lsp' }) > 0 then
      -- Stop LSP
      vim.cmd('LspStop ruby_lsp')
    end

    -- Remove .ruby-lsp folder if it exists
    rmdir('.ruby-lsp')

    -- Run gem update ruby-lsp
    update_ruby_lsp(function()
      -- Start LSP
      vim.cmd('LspStart ruby_lsp')
    end)
  end, { desc = 'Update the Ruby LSP server' })
end

require('ruby-lsp.codelens').setup_codelens()

return ruby_lsp
