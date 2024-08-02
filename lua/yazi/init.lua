local Config = require("yazi.config")
local YaziPowerInstance = require("yazi.instance").PowerInstance
local keymap_utils = require("utils.keymap")

local M = {}

---@type YaziPowerInstance | nil
local instance

-- Reveal the current file in yazi
local function reveal_current_file()
  if not instance then return end
  local path = instance:prev_filepath()
  instance:reveal(path)
end

-- Open the current file in a new tab
local function open_in_new_tab()
  if not instance then return end
  local path = instance:prev_filepath()
  vim.cmd(([[tabnew %s]]):format(path))
end

-- Open the current file in a new window
local function open_in_new_window()
  if not instance then return end
  local path = instance:prev_filepath()
  vim.cmd(([[vsplit %s]]):format(path))
end

---@param config YaziConfig.config
M.setup = function(config)
  Config:setup(config)

  keymap_utils.create("n", Config.value.keymaps.open, function()
    local current_win = vim.api.nvim_get_current_win()

    if not instance then
      instance = YaziPowerInstance.new()

      instance:on_open(function(payload)
        instance:hide()
        vim.cmd(([[edit %s]]):format(instance.focus.url))
      end)

      local main_popup = instance.layout.underlay_popups.main

      instance:on_quit(function() instance:hide() end)
      instance:on_exited(function() instance = nil end)
      instance:start()

      main_popup:map(
        Config.value.keymaps.hide,
        "Hide",
        function() instance:hide() end
      )

      if Config.value.keymaps.reveal_current_file then
        main_popup:map(
          Config.value.keymaps.reveal_current_file,
          "Reveal current file",
          reveal_current_file
        )
      end

      if Config.value.keymaps.open_in_new_tab then
        main_popup:map(
          Config.value.keymaps.open_in_new_tab,
          "Open in new tab",
          open_in_new_tab
        )
      end

      if Config.value.keymaps.open_in_new_window then
        main_popup:map(
          Config.value.keymaps.open_in_new_window,
          "Open in new window",
          open_in_new_window
        )
      end
    else
      instance:show_and_focus()
      instance._prev_win = current_win
    end
  end)
end

return M
