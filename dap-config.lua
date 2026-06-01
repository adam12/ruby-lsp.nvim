return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',
  },
  config = function()
    local dap = require('dap')
    local dapui = require('dapui')

    dapui.setup()
    vim.fn.sign_define('DapBreakpoint', {
      text = '',
      texthl = 'DapBreakpoint',
      linehl = '',
      numhl = '',
    })
    vim.api.nvim_set_hl(0, 'DapBreakpoint', { fg = '#c94f6d' })

    local dapui_open = function() dapui.open() end
    local dapui_close = function() dapui.close() end
    dap.listeners.before.attach.dapui_config = dapui_open
    dap.listeners.before.launch.dapui_config = dapui_open
    dap.listeners.after.event_initialized.dapui_config = dapui_open
    dap.listeners.before.event_terminated.dapui_config = dapui_close
    dap.listeners.before.event_exited.dapui_config = dapui_close
  end,
  keys = {
    {
      '<leader>dc',
      function() require('dap').continue() end,
      desc = 'DAP Connect',
    },
    {
      '<leader>dd',
      function() require('dap').disconnect() end,
      desc = 'DAP Disconnect',
    },
    {
      '<leader>dl',
      function() require('dapui').toggle() end,
      desc = 'DAP UI toggle',
    },
    {
      '<leader>db',
      function() require('dap').toggle_breakpoint() end,
      desc = 'DAP toggle breakpoint',
    },
    -- vim.keymap.set("n", "<F10>", function() require("dap").step_over() end)
    -- vim.keymap.set("n", "<F11>", function() require("dap").step_into() end)
    -- vim.keymap.set("n", "<F12>", function() require("dap").step_out() end)
    -- vim.keymap.set("n", "<Leader>b", function() require("dap").toggle_breakpoint() end)
    -- vim.keymap.set("n", "<Leader>B", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end)
    -- vim.keymap.set("n", "<Leader>lp",
    --   function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: ")) end)
    -- vim.keymap.set("n", "<Leader>dr", function() require("dap").repl.open() end)
    -- vim.keymap.set("n", "<Leader>dl", function() require("dap").run_last() end)
  },
}
