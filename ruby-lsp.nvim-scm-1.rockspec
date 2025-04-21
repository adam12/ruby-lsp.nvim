---@diagnostic disable: lowercase-global

local _MODREV, _SPECREV = "scm", "-1"
rockspec_format = "3.0"
version = _MODREV .. _SPECREV

local user = "adam12"
package = "ruby-lsp.nvim"

description = {
	summary = "A small shim around ensuring that the ruby-lsp gem is installed for the current Ruby version, as well as configuring lspconfig to start the Ruby LSP for Ruby files.",
	labels = { "neovim" },
	homepage = "https://github.com/" .. user .. "/" .. package,
	license = "MIT",
}

test_dependencies = {
	"nlua",
}

source = {
	url = "git://github.com/" .. user .. "/" .. package,
}

build = {
	type = "builtin",
}
