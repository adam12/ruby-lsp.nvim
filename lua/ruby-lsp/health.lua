local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local error = health.error or health.report_error
local info = health.info or health.report_info

local required_plugins = {
	{ lib = "plenary", optional = false },
	{ lib = "lspconfig", optional = false },
}

local external_dependencies = {
	{ name = "ruby" },
	{ name = "ruby-lsp" },
}

local function lualib_installed(name)
	local ok, _ = pcall(require, name)
	return ok
end

local function binary_info(name)
	if vim.fn.executable(name) ~= 1 then
		return false
	end

	local handle = io.popen(name .. " --version 2>&1 && which " .. name .. " 2>&1")
	if not handle then
		return false
	end

	local output = handle:read("*a")
	handle:close()

	local lines = {}
	for line in output:gmatch("[^\r\n]+") do
		table.insert(lines, vim.trim(line))
	end

	local version = lines[1] or "unknown version"
	local location = lines[2] or "unknown location"
	return true, version, location
end

local M = {}

M.check = function()
	-- Check Lua plugins
	start("Checking for required plugins")
	for _, plugin in ipairs(required_plugins) do
		if lualib_installed(plugin.lib) then
			ok(plugin.lib .. " installed.")
		else
			local msg = plugin.lib .. " not found."
			if plugin.optional then
				warn(msg)
			else
				error(msg)
			end
		end
	end

	-- Check external binaries
	start("Checking for external dependencies")
	for _, dep in ipairs(external_dependencies) do
		local installed, version, location = binary_info(dep.name)
		if installed then
			ok(("%s: found %s\n - %s"):format(dep.name, version, location))
		else
			error(dep.name .. " not found.")
		end
	end

	-- Stub for linter/formatter check
	start("Checking for configured linters")
	if vim.fn.filereadable(".standard.yml") == 1 then
		local installed, version, location = binary_info("standardrb")
		ok(("%s: found %s\n - %s"):format("standardrb", version, location))
	elseif vim.fn.filereadable(".rubocop.yml") == 1 then
		local installed, version, location = binary_info("rubocop")
		ok(("%s: found %s\n - %s"):format("rubocop", version, location))
	else
		info("None configured.")
	end

	-- You could parse `require("lspconfig").ruby_lsp.setup()` options
	-- or check logs or global vars if ruby-lsp exposes anything.

	-- Example of deeper checks, if desired:
	-- local config = require("lspconfig").configs["ruby-lsp"]
	-- if config then info("ruby-lsp is configured") end
end

return M
