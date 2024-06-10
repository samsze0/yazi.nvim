local opts_utils = require("utils.opts")

---@alias YaziNotifier { info?: fun(message: string), warn?: fun(message: string), error?: fun(message: string) }
---@alias YaziKeymapsOptions { move_to_pane?: { left?: string, down?: string, up?: string, right?: string }, remote_scroll_preview_pane?: { up?: string, down?: string, left?: string, right?: string } }
---@alias YaziSetupOptions { keymaps?: YaziKeymapsOptions, default_extra_args?: ShellOpts, default_extra_env_vars?: ShellOpts }

local config = {
  notifier = {
    info = function(message) vim.notify(message, vim.log.levels.INFO) end,
    warn = function(message) vim.notify(message, vim.log.levels.WARN) end,
    error = function(message) vim.notify(message, vim.log.levels.ERROR) end,
  },
  keymaps = {
    move_to_pane = {
      left = "<C-s>",
      down = "<C-d>",
      up = "<C-e>",
      right = "<C-f>",
    },
    remote_scroll_preview_pane = {
      up = "<S-Up>",
      down = "<S-Down>",
      left = "<S-Left>",
      right = "<S-Right>",
    },
  },
  default_extra_args = {},
  default_extra_env_vars = {},
}

return config
