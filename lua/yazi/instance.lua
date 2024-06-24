local Controller = require("yazi.controller").Controller
local SinglePaneLayout = require("yazi.layout").SinglePaneLayout
local DualPaneLayout = require("yazi.layout").DualPaneLayout
local config = require("yazi.config").config
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")

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

---@param opts? YaziCreateInstanceOptions
---@return YaziInstance
function Instance.new(opts)
  local obj = Controller.new(opts)
  setmetatable(obj, Instance)
  ---@cast obj YaziInstance
  return obj
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

---@param opts? YaziCreateInstanceOptions
---@return YaziBasicInstance
function BasicInstance.new(opts)
  local obj = Instance.new(opts)
  setmetatable(obj, BasicInstance)
  ---@cast obj YaziBasicInstance

  local layout = SinglePaneLayout.new({})
  obj.layout = layout

  Instance._setup_controller_ui_hooks(obj)

  return obj
end

---@class YaziPowerInstance: YaziInstance
---@field layout YaziDualPaneLayout
local PowerInstance = {}
PowerInstance.__index = PowerInstance
PowerInstance.__is_class = true
setmetatable(PowerInstance, { __index = Instance })

M.PowerInstance = PowerInstance

---@param opts? YaziCreateInstanceOptions
---@return YaziPowerInstance
function PowerInstance.new(opts)
  local obj = Instance.new(opts)
  setmetatable(obj, PowerInstance)
  ---@cast obj YaziPowerInstance

  local layout = DualPaneLayout.new({})
  obj.layout = layout

  obj:_setup_filepreview({})
  Instance._setup_controller_ui_hooks(obj)

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

    if not focus then
      self.layout:maximise_popup("main")
      self:set_preview_visibility(false)
      return
    end

    if vim.fn.filereadable(focus.url) == 1 then
      -- TODO: maximizing main popup is broken
      -- self.layout:restore_layout()
      self:set_preview_visibility(false)
      self.layout.side_popup:show_file_content(focus.url)
    else
      -- self.layout:maximise_popup("main")
      self:set_preview_visibility(true)
    end
  end)
end

return M
