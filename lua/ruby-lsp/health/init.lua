local health = vim.health or require('health')
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

local util = require('ruby-lsp.health.util')

local required_plugins = {
  { name = 'plenary' },
  { name = 'lspconfig' },
}

local external_dependencies = {
  { name = 'ruby' },
  { name = 'ruby-lsp' },
}

local linters = {
  { name = 'standardrb', config = '.standard.yml' },
  { name = 'rubocop', config = '.rubocop.yml' },
}

local M = {}

M.check = function()
  -- Check Lua plugins
  start('Checking for required plugins')
  for _, plugin in ipairs(required_plugins) do
    if util.lualib_installed(plugin.name) then
      ok(plugin.name .. ' installed.')
    else
      local msg = plugin.name .. ' not found.'
      error(msg)
    end
  end

  -- Check external binaries
  start('Checking for external dependencies')
  for _, dep in ipairs(external_dependencies) do
    local installed, version, location = util.binary_info(dep.name)
    if installed then
      ok(('%s\n - Version: %s\n - Location: %s'):format(dep.name, version, location))
    else
      error(dep.name .. ' not found.')
    end
  end

  -- Check configured linter/formatters
  start('Checking for configured linters/formatters')
  local present_linters = util.present_linters(linters)
  if next(present_linters) == nil then
    info('None configured.')
  else
    for _, present_linter in ipairs(present_linters) do
      local installed, version, location = util.binary_info(present_linter.name)
      if installed then
        ok(('%s\n - Version: %s\n - Location: %s'):format(present_linter.name, version, location))
      else
        error(('%s configuration is present, but not installed.'):format(present_linter.name))
      end
    end
  end
end

return M
