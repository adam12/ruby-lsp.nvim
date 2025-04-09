local M = {}

M.lualib_installed = function(name)
	local ok, _ = pcall(require, name)
	return ok
end

M.binary_info = function(name)
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

M.configuration_present = function(config_filename)
	return vim.fn.filereadable(config_filename) == 1
end

M.check_linter = function(name, config_file)
	if M.configuration_present(config_file) then
		return true, name
	end
end

return M
