local BaseInstanceTrait = require("tui.instance-trait")
local YaziController = require("yazi.controller")
local DualPaneLayout = require("tui.layout").DualPaneLayout
local config = require("yazi.config").value
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

---@class YaziPowerInstance: YaziController
---@field layout TUIDualPaneLayout
local PowerInstance = {}
PowerInstance.__index = PowerInstance
PowerInstance.__is_class = true
setmetatable(PowerInstance, { __index = YaziController })

M.PowerInstance = PowerInstance

---@param opts? YaziCreateControllerOptions
---@return YaziPowerInstance
function PowerInstance.new(opts)
  local obj = YaziController.new(opts)
  setmetatable(obj, PowerInstance)
  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast obj YaziPowerInstance

  obj.layout = DualPaneLayout.new({
    config = obj._config,
  })

  obj:_setup_filepreview({})
  BaseInstanceTrait.setup_controller_ui_hooks(obj)

  return obj
end

-- Show preview in Neovim instead of in yazi
--
---@param val boolean
function PowerInstance:show_preview_in_nvim(val)
  if self.preview_visible == not val then return end

  -- FIX: main pooup layout "breaks" when resized
  if val then
    -- self.layout:restore_layout()
  else
    -- self.layout:maximise_popup("main")
  end
  self:set_preview_visibility(not val)
end

-- Configure file preview
--
---@param opts? { }
function PowerInstance:_setup_filepreview(opts)
  opts = opts_utils.extend({}, opts)

  -- TODO: uncomment this once we are able to determine the hover entry type in yazi
  -- self:on_preview_visibility(function(payload)
  --   if self.preview_visible then return end
  --
  --   local focus = self.focus
  --   if not focus then
  --     vim.warn("No focus entry")
  --     return
  --   end
  --
  --   self.layout.side_popup:show_file_content(focus.url)
  -- end)

  local filetypes_to_skip_preview = {}

  self:on_hover(function(payload)
    local success = self.layout.side_popup:show_file_content(payload.url, {
      exclude_filetypes = filetypes_to_skip_preview
    })
    self:show_preview_in_nvim(success)
  end)
end

return M
