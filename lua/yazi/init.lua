local Config = require("yazi.config")
local YaziPowerInstance = require("yazi.instance").PowerInstance

local M = {}

---@param config? YaziConfig.config
M.setup = function(config) Config:setup(config) end

---@type YaziPowerInstance | nil
local instance

-- Open yazi, create a singleton instance if it does not exist yet
function M.open()
  local current_win = vim.api.nvim_get_current_win()

  if not instance then
    instance = YaziPowerInstance.new()

    instance:on_open(function(payload)
      instance:hide()
      vim.cmd(([[edit %s]]):format(instance.focus.url))
    end)

    instance:on_quit(function() instance:hide() end)
    instance:on_exited(function() instance = nil end)
    instance:start()
  else
    instance:show_and_focus()
    instance._prev_win = current_win
  end
end

-- Hide yazi
function M.hide()
  if not instance then return end
  instance:hide()
end

-- Reveal the current file in yazi
function M.reveal_current_file()
  if not instance then return end
  local path = instance:prev_filepath()
  instance:reveal(path)
end

-- Open the current file in a new tab
function M.open_in_new_tab()
  if not instance then return end
  local path = instance:prev_filepath()
  vim.cmd(([[tabnew %s]]):format(path))
end

-- Open the current file in a new window
function M.open_in_new_window()
  if not instance then return end
  local path = instance:prev_filepath()
  vim.cmd(([[vsplit %s]]):format(path))
end

return M
