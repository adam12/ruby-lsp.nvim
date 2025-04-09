local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

local required_plugins = {
	{ lib = "plenary" },
	{ lib = "lspconfig" },
}

local external_dependencies = {
	{ name = "ruby" },
	{ name = "ruby-lsp" },
}

local util = require("ruby-lsp.health.util")

local M = {}

M.check = function()
	-- Check Lua plugins
	start("Checking for required plugins")
	for _, plugin in ipairs(required_plugins) do
		if util.lualib_installed(plugin.lib) then
			ok(plugin.lib .. " installed.")
		else
			local msg = plugin.lib .. " not found."
			error(msg)
		end
	end

	-- Check external binaries
	start("Checking for external dependencies")
	for _, dep in ipairs(external_dependencies) do
		local installed, version, location = util.binary_info(dep.name)
		if installed then
			ok(("%s: found %s\n - %s"):format(dep.name, version, location))
		else
			error(dep.name .. " not found.")
		end
	end

	-- Stub for linter/formatter check
	start("Checking for configured linters")
	if vim.fn.filereadable(".standard.yml") == 1 then
		local installed, version, location = util.binary_info("standardrb")
		if installed then
		 	ok(("%s: found %s\n - %s"):format("standardrb", version, location))
		else
			error(("%s configuration is present, but not installed.")):format("standardrb")
		end
	elseif vim.fn.filereadable(".rubocop.yml") == 1 then
		local installed, version, location = util.binary_info("rubocop")
		if installed then
			ok(("%s: found %s\n - %s"):format("rubocop", version, location))
		else
			error(("%s configuration is present, but not installed.")):format("rubocop")
		end
	else
		info("None configured.")
	end
end

return M
