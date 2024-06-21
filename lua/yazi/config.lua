local opts_utils = require("utils.opts")

---@alias YaziNotifier { info?: fun(message: string), warn?: fun(message: string), error?: fun(message: string) }
---@alias YaziKeymapsOptions { move_to_pane?: { left?: string, down?: string, up?: string, right?: string }, remote_scroll_preview_pane?: { up?: string, down?: string, left?: string, right?: string }, toggle_maximise?: string, copy_filepath_to_clipboard?: string, show_help?: string, hide_help?: string, file_open?: { new_window?: string, new_tab?: string, current_window?: string } }
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
