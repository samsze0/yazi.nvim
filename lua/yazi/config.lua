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

---@class YaziKeymapsOptions.remote_scroll_preview_pane
---@field up string?
---@field down string?
---@field left string?
---@field right string?

---@class YaziKeymapsOptions.file_open
---@field new_window string?
---@field new_tab string?
---@field current_window string?

---@class YaziKeymapsOptions
---@field move_to_pane YaziKeymapsOptions.move_to_pane?
---@field remote_scroll_preview_pane YaziKeymapsOptions.remote_scroll_preview_pane?
---@field toggle_maximise string?
---@field copy_filepath_to_clipboard string?
---@field show_help string?
---@field hide_help string?
---@field file_open YaziKeymapsOptions.file_open?

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
    remote_scroll_preview_pane = {
      up = "<S-Up>",
      down = "<S-Down>",
      left = "<S-Left>",
      right = "<S-Right>",
    },
    toggle_maximise = "<C-z>",
    copy_filepath_to_clipboard = "<C-y>",
    show_help = "<C-?>",
    hide_help = "q",
    file_open = {
      new_window = "<C-w>",
      new_tab = "<C-t>",
      current_window = "<C-CR>",
    },
  },
  default_extra_args = {},
  default_extra_env_vars = {},
}

M.config = M.default_config

---@param opts? YaziSetupOptions
function M.setup(opts) M.config = opts_utils.deep_extend(M.default_config, opts) end

return M
