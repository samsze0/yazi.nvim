local Config = require("tui.config")
local opts_utils = require("utils.opts")

---@class YaziKeymapsConfig : TUIKeymapsConfig
---@field open string
---@field hide string
---@field reveal_current_file? string
---@field open_in_new_tab? string
---@field open_in_new_window? string

---@class YaziConfig.config : TUIConfig.config
---@field hover_event_debounce_ms? number
---@field scroll_preview_event_debounce_ms? number
---@field keymaps YaziKeymapsConfig

---@class YaziConfig: TUIConfig
---@field value YaziConfig.config
local YaziConfig = {}
YaziConfig.__index = YaziConfig
YaziConfig.__is_class = true
setmetatable(YaziConfig, { __index = Config })

---@return YaziConfig
function YaziConfig.new()
  local obj = setmetatable(Config.new(), YaziConfig)
  ---@cast obj YaziConfig

  obj.value = opts_utils.deep_extend(obj.value, {
    hover_event_debounce_ms = 100,
    scroll_preview_event_debounce_ms = 100,
  })

  return obj
end

---@param config YaziConfig.config
function YaziConfig:setup(config)
  self.value = opts_utils.deep_extend(self.value, config)
end

return YaziConfig.new()
