local BaseInstanceTrait = require("tui.instance-trait")
local YaziController = require("yazi.controller")
local DualPaneLayout = require("tui.layout").DualPaneLayout
local config = require("yazi.config").value
local opts_utils = require("utils.opts")
local lang_utils = require("utils.lang")
local terminal_utils = require("utils.terminal")
local tbl_utils = require("utils.table")
local terminal_filetype = require("terminal-filetype")

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
  ["--color"] = "always"
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
  if vim.fn.executable("eza") ~= 1 then
    error("eza is not installed")
  end

  self:on_hover(function(payload)
    self:show_preview_in_nvim(true)

    self.layout.side_popup:set_lines({})

    local type = vim.fn.getftype(payload.url)
    if type == "dir" then
      local command = ("eza %s %s"):format(payload.url, terminal_utils.shell_opts_tostring(eza_options))
      local eza_output = terminal_utils.systemlist_unsafe(command, {
        trim_endline = true,
      })

      self.layout.side_popup:set_lines(eza_output, { filetype = "txt" })
      terminal_filetype.refresh_highlight(self.layout.side_popup.bufnr)
      return
    end

    local success = self.layout.side_popup:show_file_content(payload.url, {
      exclude_filetypes = filetypes_to_skip_preview
    })
    -- self:show_preview_in_nvim(success)
  end)
end

return M
