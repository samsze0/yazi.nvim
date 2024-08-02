local TUIBaseInstanceMixin = require("tui.instance-mixin")
local YaziController = require("yazi.controller")
local Layout = require("tui.layout").Layout
local OverlayPopupSettings = require("tui.layout").OverlayPopupSettings
local UnderlayPopupSettings = require("tui.layout").UnderlayPopupSettings
local config = require("yazi.config").value
local opts_utils = require("utils.opts")
local TUIPopup = require("tui.popup").TUI
local UnderlayPopup = require("tui.popup").Underlay
local HelpPopup = require("tui.popup").Help
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local NuiLayout = require("nui.layout")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

local M = {}

---@class YaziPowerInstance.layout : TUILayout
---@field underlay_popups { main: TUITUIPopup, preview: TUIUnderlayPopup }

---@class YaziPowerInstance: YaziController
---@field layout YaziPowerInstance.layout
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

  local main_popup = TUIPopup.new({
    config = obj._config,
  })
  local preview_popup = UnderlayPopup.new({
    nui_popup_opts = {
      win_options = {
        number = true,
        cursorline = true,
      },
    },
    config = obj._config,
  })
  local help_popup = HelpPopup.new({
    config = obj._config,
  })

  local main_popup_settings = UnderlayPopupSettings.new({
    right = preview_popup
  })
  local preview_popup_settings = UnderlayPopupSettings.new({
    left = main_popup
  })

  local layout = Layout.new({
    config = obj._config,
    underlay_popups = {
      main = main_popup,
      preview = preview_popup,
    },
    overlay_popups = {
      help = help_popup,
    },
    underlay_popups_settings = {
      main = main_popup_settings,
      preview = preview_popup_settings,
    },
    box_fn = function()
      -- FIX: NuiPopup does not cater for removing popup from layout
      return NuiLayout.Box({
        NuiLayout.Box(main_popup:get_nui_popup(), { grow = main_popup_settings.visible and 1 or 0 }),
        NuiLayout.Box(
          preview_popup:get_nui_popup(),
          { grow = preview_popup_settings.visible and 1 or 0 }
        ),
      }, { dir = "row" })
    end,
  })
  ---@cast layout YaziPowerInstance.layout
  obj.layout = layout

  obj:_setup_filepreview({})
  TUIBaseInstanceMixin.setup_controller_ui_hooks(obj) --- @diagnostic disable-line: param-type-mismatch

  return obj
end

-- FIX: main pooup layout "breaks" when resized
--
-- Show preview in Neovim instead of in yazi
--
---@param val boolean
function PowerInstance:show_preview_in_nvim(val)
  if self.preview_visible == not val then return end

  -- if val then
  --   self.layout:restore_layout()
  -- else
  --   self.layout:maximise_popup("main")
  -- end
  self:set_preview_visibility(not val)
end

-- TODO: move to config
local filetypes_to_skip_preview = {}
---@type ShellOpts
local eza_options = {
  ["--long"] = true,
  ["--no-permissions"] = true,
  ["--no-filesize"] = true,
  ["--no-time"] = true,
  ["--no-user"] = true,
  ["--group-directories-first"] = true,
  ["--all"] = true,
  ["--icons"] = "always",
  ["--color"] = "never",
}

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

  -- TODO: use native preview of yazi instead of exa
  if vim.fn.executable("eza") ~= 1 then error("eza is not installed") end

  local preview_popup = self.layout.underlay_popups.preview

  self:on_hover(function(payload)
    self:show_preview_in_nvim(true)

    preview_popup:set_lines({})

    local type = vim.fn.getftype(payload.url)
    if type == "dir" then
      local command = ("eza '%s' %s"):format(
        payload.url,
        terminal_utils.shell_opts_tostring(eza_options)
      )
      local eza_output = terminal_utils.systemlist_unsafe(command, {
        trim_endline = true,
      })

      -- FIX: ansi colors are not displayed correctly
      -- FIX: terminal.vim syntax have no effect after switching filetype back and forth
      preview_popup:set_lines(
        eza_output,
        { filetype = "terminal" }
      )
      return
    end

    local success =
      preview_popup:show_file_content(payload.url, {
        exclude_filetypes = filetypes_to_skip_preview,
      })
    -- self:show_preview_in_nvim(success)
  end)
end

return M
