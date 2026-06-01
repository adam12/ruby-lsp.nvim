local ruby_lsp = {}
local Job = require('plenary.job')
local uv = vim.uv or vim.loop
local has_native_lsp_config = vim.fn.has('nvim-0.11') == 1

local logger = require('ruby-lsp/logger')

local function rmdir(dir)
  local handle = uv.fs_scandir(dir)
  if handle then
    while true do
      local name, type = uv.fs_scandir_next(handle)
      if not name then break end

      local path = dir .. '/' .. name
      if type == 'directory' then
        rmdir(path)
      else
        uv.fs_unlink(path)
      end
    end
    uv.fs_rmdir(dir)
  end
end

local function is_standard() return vim.fn.filereadable('.standard.yml') == 1 end

local function is_rubocop() return vim.fn.filereadable('.rubocop.yml') == 1 end

local function detect_tool()
  if is_standard() then return 'standard' end

  if is_rubocop() then return 'rubocop' end
end

local function build_effective_config(user_config)
  local effective = vim.deepcopy(user_config)

  -- 'mason' is a LazyVim/lspconfig-framework sentinel, not a real LSP field
  effective.mason = nil

  -- Default cmd, copying any user-supplied table so we don't mutate it
  local cmd = vim.list_extend({}, effective.cmd or { 'ruby-lsp' })
  if ruby_lsp.options.use_launcher then table.insert(cmd, '--use-launcher') end
  effective.cmd = cmd

  if ruby_lsp.options.autodetect_tools then
    local tool = detect_tool()
    if tool then
      effective.init_options = vim.tbl_extend('force', effective.init_options or {}, {
        formatter = tool,
        linters = { tool },
      })
    end
  end

  effective.handlers = vim.tbl_extend('force', logger.handlers(), effective.handlers or {})

  -- nvim-lspconfig's ruby_lsp reuse_client stamps conf.cmd_cwd = conf.root_dir
  -- then compares client.config.cmd_cwd to conf.cmd_cwd. But the first client
  -- ever spawned has no peers, so reuse_client is never called against it and
  -- its cmd_cwd stays nil; the next buffer's reuse check then sees nil and
  -- spawns a duplicate. Fall back to root_dir (the source of cmd_cwd) so the
  -- first client matches. Multi-root setups still spawn distinct clients
  -- because their root_dir values differ.
  effective.reuse_client = effective.reuse_client
    or function(client, conf)
      conf.cmd_cwd = conf.cmd_cwd or conf.root_dir
      local client_cwd = client.config.cmd_cwd or client.config.root_dir
      return client.name == conf.name and client_cwd == conf.cmd_cwd
    end

  return effective
end

local function configure_lspconfig(config)
  local effective = build_effective_config(config)

  if has_native_lsp_config then
    vim.lsp.config('ruby_lsp', effective)
    vim.lsp.enable('ruby_lsp')
  else
    require('lspconfig').ruby_lsp.setup(effective)
  end
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

ruby_lsp.config = {
  auto_install = true,
  use_launcher = false, -- DEPRECATED: appends --use-launcher to cmd
  autodetect_tools = false, -- Autodetect the formatting and linting tools
  lspconfig = {
    mason = false, -- Prevent LazyVim from installing via Mason
    on_attach = function(_client, _buffer) end,
    on_init = function(_client, _initialize_result) end,
  },
}

ruby_lsp.setup = function(config)
  if config and config.use_launcher ~= nil then
    vim.deprecate('ruby-lsp.nvim option: use_launcher', nil, nil, 'ruby-lsp.nvim')
  end

  ruby_lsp.options = vim.tbl_deep_extend('force', {}, ruby_lsp.config, config or {})

  local user_on_attach = ruby_lsp.options.lspconfig.on_attach
  ruby_lsp.options.lspconfig.on_attach = function(client, buffer)
    create_autocmds(client, buffer)
    user_on_attach(client, buffer)
  end

  local user_on_init = ruby_lsp.options.lspconfig.on_init
  ruby_lsp.options.lspconfig.on_init = function(client, initialize_result)
    logger.log_initialize(initialize_result)
    user_on_init(client, initialize_result)
  end

  local server_started = false

  local function start_server()
    configure_lspconfig(ruby_lsp.options.lspconfig)
    if not has_native_lsp_config then
      -- On 0.11+, configure_lspconfig called vim.lsp.enable, which attaches
      -- to already-loaded matching buffers on its own.
      vim.cmd('LspStart ruby_lsp')
    end
  end

  local function start_ruby_lsp()
    if server_started then return end
    -- This should only be necessary once per vim session
    server_started = true

    if not is_ruby_lsp_installed() and ruby_lsp.options.auto_install then
      install_ruby_lsp(start_server)
    else
      start_server()
    end
  end

  -- Autocommand to only install ruby-lsp server when opening a Ruby file
  vim.api.nvim_create_autocmd('FileType', {
    pattern = { 'ruby', 'eruby' },
    callback = start_ruby_lsp,
    once = true,
  })

  -- If a Ruby buffer is already loaded (e.g. plugin lazy-loaded after open),
  -- the FileType event already fired and the autocmd above would never trigger.
  if vim.bo.filetype == 'ruby' or vim.bo.filetype == 'eruby' then start_ruby_lsp() end

  -- Autocommand to update ruby-lsp
  vim.api.nvim_create_user_command('RubyLspUpdate', function()
    local clients = vim.lsp.get_clients({ name = 'ruby_lsp' })
    if has_native_lsp_config then
      for _, client in ipairs(clients) do
        client:stop()
      end
    elseif #clients > 0 then
      vim.cmd('LspStop ruby_lsp')
    end

    -- Remove .ruby-lsp folder if it exists
    rmdir('.ruby-lsp')

    -- Run gem update ruby-lsp
    update_ruby_lsp(function()
      if has_native_lsp_config then
        -- Re-enable: clients were stopped above; enable() re-attaches to
        -- already-loaded matching buffers.
        vim.lsp.enable('ruby_lsp')
      else
        vim.cmd('LspStart ruby_lsp')
      end
    end)
  end, { desc = 'Update the Ruby LSP server' })
end

require('ruby-lsp.codelens').setup_codelens()

return ruby_lsp
