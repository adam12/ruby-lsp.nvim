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

local function install_ruby_lsp()
  vim.notify('Installing ruby-lsp...')

  Job:new({
    command = 'gem',
    args = { 'install', 'ruby-lsp' },
    on_exit = function(_j, return_val)
      if return_val == 0 then
        vim.schedule(function()
          vim.notify('Installation of ruby-lsp complete!')
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
  lspconfig = {
    mason = false, -- Prevent LazyVim from installing via Mason
    on_attach = function(client, buffer)
      create_autocmds(client, buffer)
    end,
  },
}

ruby_lsp.setup = function(config)
  local options = vim.tbl_deep_extend('force', {}, ruby_lsp.config, config or {})

  if not is_ruby_lsp_installed() and options.auto_install then
    install_ruby_lsp()
  end

  configure_lspconfig(options.lspconfig)
end


return ruby_lsp
