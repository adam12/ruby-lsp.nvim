# Ruby LSP for Neovim

This Neovim plugin is a small shim around ensuring that the ruby-lsp gem is
installed for the current Ruby version, as well as configuring lspconfig to
start the Ruby LSP for Ruby files.

## Installation

With Lazy.nvim, add the following to your configuration

```lua
{
  'adam12/ruby-lsp.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'neovim/nvim-lspconfig',
  },
  config = true,
}
```

## Usage

Just open Neovim. The Ruby LSP should be installed if not present, and Neovim
will be configured to start the Ruby LSP when opening a Ruby file.

If you'd like to disable the auto-install:

```lua
{
  'adam12/ruby-lsp.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'neovim/nvim-lspconfig',
  },
  config = true,
  opts = {
    auto_install = false,
  },
}
```

If you want to pass configuration to lspconfig:

```lua
{
  'adam12/ruby-lsp.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'neovim/nvim-lspconfig',
  },
  config = true,
  opts = {
    lspconfig = {
      init_options = {
        formatter = 'standard',
        linters = { 'standard' },
      },
    },
  },
}
```
