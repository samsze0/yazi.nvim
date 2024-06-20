local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local EventMap = require("yazi.event-map")
local str_utils = require("utils.string")

---@class YaziIpcClient
---@field _event_map YaziEventMap Map of events to lua callbacks
local YaziIpcClient = {}
YaziIpcClient.__index = YaziIpcClient
YaziIpcClient.__is_class = true

function YaziIpcClient.new()
  local obj = setmetatable({
    _event_map = EventMap.new(),
  }, YaziIpcClient)

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
  self._event_map:append(event, callback)
  -- TODO
  return function() error("Not implemented") end
end

-- Destroy the yazi client by freeing up any occupied resources
function YaziIpcClient:destroy()
  -- TODO
end

function YaziIpcClient:on_message(message)
  local ok, parts = pcall(
    function()
      return str_utils.split(message, {
        sep = ",",
        count = 3,
      })
    end
  )
  if not ok then
    vim.error("Invalid message format: ", message)
    return
  end
  local event = parts[1]
  local message = vim.json.decode(parts[4])

  local callbacks = self._event_map:get(event)
  for _, callback in ipairs(callbacks) do
    callback(message)
  end
end

return YaziIpcClient
