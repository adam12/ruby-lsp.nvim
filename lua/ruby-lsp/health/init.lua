local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

local util = require("ruby-lsp.health.util")

local required_plugins = {
	{ name = "plenary" },
	{ name = "lspconfig" },
}

local external_dependencies = {
	{ name = "ruby" },
	{ name = "ruby-lsp" },
}

local M = {}

M.check = function()
	-- Check Lua plugins
	start("Checking for required plugins")
	for _, plugin in ipairs(required_plugins) do
		if util.lualib_installed(plugin.name) then
			ok(plugin.name .. " installed.")
		else
			local msg = plugin.name .. " not found."
			error(msg)
		end
	end

	-- Check external binaries
	start("Checking for external dependencies")
	for _, dep in ipairs(external_dependencies) do
		local installed, version, location = util.binary_info(dep.name)
		if installed then
			ok(("%s\n - Version: %s\n - Location: %s"):format(dep.name, version, location))
		else
			error(dep.name .. " not found.")
		end
	end

	-- Check configured linter/formatters
	start("Checking for configured linters")
	if vim.fn.filereadable(".standard.yml") == 1 then
		local installed, version, location = util.binary_info("standardrb")
		if installed then
			ok(("standardrb\n - Version: %s\n - Location: %s"):format(version, location))
		else
			error("standardrb configuration is present, but not installed.")
		end
	elseif vim.fn.filereadable(".rubocop.yml") == 1 then
		local installed, version, location = util.binary_info("rubocop")
		if installed then
			ok(("rubocop\n - Version: %s\n - Location: %s"):format(version, location))
		else
			error("rubocop configuration is present, but not installed.")
		end
	else
		info("None configured.")
	end

	-- TODO: add LSP logs? can we ping the LSP server to see if it's running?
	-- something like "Check Ruby-LSP logs" - to be implemented with the ring buffer
end
return M
