local Controller = require("yazi.controller").Controller
local SinglePaneLayout = require("yazi.layout").SinglePaneLayout
local DualPaneLayout = require("yazi.layout").DualPaneLayout
local config = require("yazi.config").config
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local safe_require = lang_utils.safe_require

---@module 'jumplist'
local jumplist = safe_require("jumplist")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

---@class YaziInstance : YaziController
---@field layout YaziLayout
local Instance = {}
Instance.__index = Instance
Instance.__is_class = true
setmetatable(Instance, { __index = Controller })

M.Instance = Instance

---@class YaziCreateInstanceOptions : YaziCreateControllerOptions

---@param opts? YaziCreateControllerOptions
---@return YaziInstance
function Instance.new(opts)
  local obj = Controller.new(opts)
  setmetatable(obj, Instance)
  ---@cast obj YaziInstance
  return obj
end

-- Configure remote navigation between main and target popup.
--
---@param target_popup YaziSidePopup
---@param opts? { }
function Instance:_setup_remote_nav_keymaps(target_popup, opts)
  opts = opts_utils.extend({}, opts)

  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview up",
    config.keymaps.remote_scroll_preview_pane.up
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview left",
    config.keymaps.remote_scroll_preview_pane.left
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview down",
    config.keymaps.remote_scroll_preview_pane.down
  )
  self.layout.main_popup:map_remote(
    target_popup,
    "Scroll preview right",
    config.keymaps.remote_scroll_preview_pane.right
  )
end

-- Configure file open keymaps
--
---@param opts? { }
function Instance:_setup_file_open_keymaps(opts)
  opts = opts_utils.extend({}, opts)

  self.layout.main_popup:map(
    config.keymaps.file_open.new_window,
    "Open in new window",
    function()
      if not self.focus then return end

      local filepath = self.focus.url
      self:hide()
      vim.cmd(([[vsplit %s]]):format(filepath))
    end
  )

  self.layout.main_popup:map(
    config.keymaps.file_open.new_tab,
    "Open in new tab",
    function()
      if not self.focus then return end

      local filepath = self.focus.url
      self:hide()
      vim.cmd(([[tabnew %s]]):format(filepath))
    end
  )

  self.layout.main_popup:map(
    config.keymaps.file_open.current_window,
    "Open",
    function()
      if not self.focus then return end

      local filepath = self.focus.url
      self:hide()
      if jumplist then jumplist.save() end
      vim.cmd(([[e %s]]):format(filepath))
    end
  )
end

-- Configure help popup
--
---@param opts? { }
function Instance:_setup_help_popup(opts)
  self.layout.help_popup:set_keymaps(self.layout.main_popup:keymaps())
end

-- Configure controller UI hooks
function Instance:_setup_controller_ui_hooks()
  self:set_ui_hooks({
    show = function() self.layout:show() end,
    hide = function() self.layout:hide() end,
    focus = function() self.layout.main_popup:focus() end,
    destroy = function() self.layout:unmount() end,
  })
end

---@class YaziBasicInstance: YaziInstance
---@field layout YaziSinglePaneLayout
local BasicInstance = {}
BasicInstance.__index = BasicInstance
BasicInstance.__is_class = true
setmetatable(BasicInstance, { __index = Instance })

M.BasicInstance = BasicInstance

---@param opts? YaziCreateControllerOptions
---@return YaziBasicInstance
function BasicInstance.new(opts)
  local obj = Instance.new(opts)
  setmetatable(obj, BasicInstance)
  ---@cast obj YaziBasicInstance

  local layout = SinglePaneLayout.new({})
  obj.layout = layout

  Instance._setup_controller_ui_hooks(obj)
  Instance._setup_file_open_keymaps(obj, {})
  Instance._setup_help_popup(obj, {})

  return obj
end

---@class YaziPowerInstance: YaziInstance
---@field layout YaziDualPaneLayout
local PowerInstance = {}
PowerInstance.__index = PowerInstance
PowerInstance.__is_class = true
setmetatable(PowerInstance, { __index = Instance })

M.PowerInstance = PowerInstance

---@param opts? YaziCreateControllerOptions
---@return YaziPowerInstance
function PowerInstance.new(opts)
  local obj = Instance.new(opts)
  setmetatable(obj, PowerInstance)
  ---@cast obj YaziPowerInstance

  local layout = DualPaneLayout.new({})
  obj.layout = layout

  Instance._setup_remote_nav_keymaps(obj.layout.side_popup, {})
  obj:_setup_filepreview({})
  Instance._setup_controller_ui_hooks(obj)
  Instance._setup_help_popup(obj, {})

  return obj
end

-- Configure file preview
--
---@param opts? { }
function PowerInstance:_setup_filepreview(opts)
  opts = opts_utils.extend({}, opts)

  self:on_hover(function(payload)
    local focus = self.focus

    self.layout.side_popup:set_lines({})

    if not focus then return end

    self.layout.side_popup:show_file_content(focus.url)
  end)

  self.layout.main_popup:map(
    config.keymaps.copy_filepath_to_clipboard,
    "Copy filepath",
    function()
      if not self.focus then return end

      local filepath = self.focus.url
      vim.fn.setreg("+", filepath)
      _info(([[Copied %s to clipboard]]):format(filepath))
    end
  )

  Instance._setup_file_open_keymaps(self, {})
end

return M
