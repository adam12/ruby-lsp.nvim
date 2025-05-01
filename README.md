# Ruby LSP for Neovim

This Neovim plugin is a small shim around ensuring that the ruby-lsp gem is
installed for the current Ruby version, as well as configuring lspconfig to
start the Ruby LSP for Ruby files.

## Why

The Ruby LSP has dependencies which include C extensions, and these extensions
are compiled against a specific version of Ruby (the Ruby ABI). When ran against
a different version of Ruby, strange things can happen.

Many people manage their LSPs in Neovim using Mason, which is a fantastic tool
for managing LSPs, but when it manages Ruby LSPs, it does so by using a single,
unversioned folder, where the Ruby version is ambiguous. This will cause the
issues as mentioned above.

The `ruby-lsp.nvim` plugin's goal is two fold:

1. Just install the `ruby-lsp` dependency using regular `gem install`, if it's
not detected when Neovim starts up. This should work perfectly for almost all
Ruby version managers.

2. Build on top of the `nvim-lspconfig` package to provide a nicer experience
out of the box where possible. This might include extra bindings or user commands,
or smoothing over oddities such as requesting Mason not manage the LSP when using
the LazyVim distribution.

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

## Code Lens

This plugin provides code lens support for some Rails-specific features:

 - `openFile` – Jump from a controller action to the corresponding view or route
    definition.
 - `runTest` – Run a test file or an individual test and display the output in a
    split window.
 - `runTask` – Run database migrations.

Code lens virtual text will be added where these features are available.

You can run available lens actions using `vim.lsp.codelens.run()`. Or, add a key
mapping:

```lua
{
  'adam12/ruby-lsp.nvim',
  ...
  keys = {
    {
      '<leader>cl',
      function()
        vim.lsp.codelens.run()
      end,
      desc = 'Run Code Lens',
    },
  },
}
```

## Disclaimer

This project is not officially connected to the Ruby LSP project, or officially
endorsed by Shopify in any way.
