local ruby_lsp = {}
local Job = require('plenary.job')

local function configure_lspconfig(config)
  local lspconfig = require('lspconfig')
  lspconfig.ruby_lsp.setup(config)
end

local function is_ruby_lsp_installed()
  return vim.fn.executable('ruby-lsp') == 1
end

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
              filename = item.path
            })
          end
        end

        vim.fn.setqflist(qf_list)
        vim.cmd('copen')
      end, buffer)
    end,
    { nargs = '?', complete = function() return { 'all' } end }
  )
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

          if callback then
            callback()
          end
        end)
      else
        vim.schedule(function()
          vim.notify('Installation of ruby-lsp failed!')
        end)
      end
    end,
    on_stderr = function(_, msg)
      vim.schedule(function()
        vim.notify(msg)
      end)
    end,
  }):start()
end

ruby_lsp.config = {
  auto_install = true,
  use_launcher = false, -- Use experimental launcher
  lspconfig = {
    mason = false, -- Prevent LazyVim from installing via Mason
    on_attach = function(client, buffer)
      create_autocmds(client, buffer)
    end,
  },
}

ruby_lsp.setup = function(config)
  ruby_lsp.options = vim.tbl_deep_extend('force', {}, ruby_lsp.config, config or {})

  local lspconfig = require('lspconfig')
  lspconfig.util.on_setup = lspconfig.util.add_hook_before(lspconfig.util.on_setup, function(c)
    if c.name == 'ruby_lsp' then
      -- Set a reasonable default if one isn't present
      if c.cmd == nil then
        c.cmd = { 'ruby-lsp' }
      end

      if ruby_lsp.options.use_launcher then
        table.insert(c.cmd, '--use-launcher')
      end
    end
  end)

  local server_started = false

  -- Autocommand to only install ruby-lsp server when opening a Ruby file
  vim.api.nvim_create_autocmd('FileType', {
    pattern = {'ruby', 'eruby'},
    callback = function()
      if not server_started then
        -- This should only be necessary once per vim session
        server_started = true

        if not is_ruby_lsp_installed() and ruby_lsp.options.auto_install then
          install_ruby_lsp(function()
            configure_lspconfig(ruby_lsp.options.lspconfig)
            -- Start the ruby lsp now that it's been configured
            vim.cmd("LspStart ruby_lsp")
          end)
        else
          configure_lspconfig(ruby_lsp.options.lspconfig)
          -- Start the ruby lsp now that it's been configured
          vim.cmd("LspStart ruby_lsp")
        end
      end
    end,
    once = true
  })
end


return ruby_lsp
