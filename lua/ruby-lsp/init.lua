local ruby_lsp = {}
local Job = require('plenary.job')

local function configure_lspconfig(config)
  local lspconfig = require('lspconfig')
  lspconfig.ruby_lsp.setup(config)
end

local function is_ruby_lsp_installed()
  return vim.fn.executable('ruby-lsp') == 1
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
