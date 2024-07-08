local Instance = require("tui.instance")
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
  Instance._setup_controller_ui_hooks(obj)

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
    -- Clear existing preview
    self.layout.side_popup:set_lines({})

    -- TODO: move logic to utils

    local type = vim.fn.getftype(payload.url)
    if type ~= "file" then
      self:show_preview_in_nvim(false)
      self.layout.side_popup:set_lines({ "Not a file" })
      return
    end

    if vim.fn.filereadable(payload.url) ~= 1 then
      self:show_preview_in_nvim(false)
      self.layout.side_popup:set_lines({ "File not readable" })
      return
    end

    -- local result, status, _ =
    --   terminal_utils.system("file --mime " .. payload.url)
    -- if status ~= 0 then
    --   _error("Failed to get file type for " .. payload.url)
    --   self.layout.side_popup:set_lines({ "Failed to get file type" })
    --   return
    -- end
    -- ---@cast result string
    -- if result:match("charset=binary") then
    --   self.layout.side_popup:set_lines({ "No preview available for binary file" })
    --   return
    -- end

    local filename = vim.fn.fnamemodify(payload.url, ":t")

    local filetype = vim.filetype.match({
      filename = filename,
    })
    if not filetype then
      _warn("Failed to get filetype for " .. filename)
      self:show_preview_in_nvim(false)
      self.layout.side_popup:set_lines({ "Failed to get filetype" })
      return
    end

    if tbl_utils.contains(filetypes_to_skip_preview, filetype) then
      self:show_preview_in_nvim(false)
      self.layout.side_popup:set_lines({
        "No preview available for filetype " .. filetype,
      })
      return
    end

    -- local num_of_lines = terminal_utils.system_unsafe("wc -l < " .. payload.url)
    -- num_of_lines = tonumber(vim.trim(num_of_lines)) ---@diagnostic disable-line: cast-local-type
    -- if not num_of_lines then
    --   _error("Failed to get number of lines for " .. payload.url)
    --   self.layout.side_popup:set_lines({ "Failed to get number of lines" })
    --   return
    -- end
    -- if num_of_lines > 10000 then
    --   self.layout.side_popup:set_lines({
    --     "File is too large to preview",
    --   })
    --   return
    -- end

    local file_size = vim.fn.getfsize(payload.url)
    -- Check if file_size exceeds 1MB
    if file_size > 1024 * 1024 then
      self:show_preview_in_nvim(false)
      self.layout.side_popup:set_lines({
        "File is too large to preview",
      })
      return
    end

    self:show_preview_in_nvim(true)
    self.layout.side_popup:show_file_content(payload.url)
  end)
end

return M
