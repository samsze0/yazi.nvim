local opts_utils = require("utils.opts")

---@class YaziNotifier
---@field info fun(message: string)?
---@field warn fun(message: string)?
---@field error fun(message: string)?

---@class YaziKeymapsOptions.move_to_pane
---@field left string?
---@field down string?
---@field up string?
---@field right string?

---@class YaziKeymapsOptions
---@field move_to_pane YaziKeymapsOptions.move_to_pane?
---@field copy_filepath_to_clipboard string?

---@alias YaziSetupOptions { keymaps?: YaziKeymapsOptions, default_extra_args?: ShellOpts, default_extra_env_vars?: ShellOpts }

local M = {}

M.default_config = {
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
    copy_filepath_to_clipboard = "<C-y>",
  },
  default_extra_args = {},
  default_extra_env_vars = {},
}

M.config = M.default_config

---@param opts? YaziSetupOptions
function M.setup(opts) M.config = opts_utils.deep_extend(M.default_config, opts) end

return M
