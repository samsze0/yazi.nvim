local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local CallbackMap = require("yazi.callback-map")

---@class YaziIpcClient
---@field _callback_map YaziCallbackMap Map of keys to lua callbacks
local YaziIpcClient = {}
YaziIpcClient.__index = YaziIpcClient
YaziIpcClient.__is_class = true

function YaziIpcClient.new()
  local obj = setmetatable({
    _callback_map = CallbackMap.new(),
  }, YaziIpcClient)

  local function message_handler(message)
    -- TODO
    -- obj._callback_map:invoke_if_exists(key, body)
  end

  return obj
end

-- Send an action to yazi to execute
--
---@param action string
function YaziIpcClient:execute(action)
  -- TODO
end

-- Subscribe to a yazi event
--
---@param event string
---@param callback function
---@return fun(): nil unsubscribe_handle
function YaziIpcClient:subscribe(event, callback)
  -- TODO
  return function() end
end

-- Destroy the yazi client by freeing up any occupied resources
function YaziIpcClient:destroy()
  -- TODO
end

return YaziIpcClient
