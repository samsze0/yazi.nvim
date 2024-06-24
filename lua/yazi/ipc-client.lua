local uuid_utils = require("utils.uuid")
local terminal_utils = require("utils.terminal")
local uv_utils = require("utils.uv")
local os_utils = require("utils.os")
local EventMap = require("yazi.event-map")
local str_utils = require("utils.string")

---@class YaziIpcClient
---@field _event_map YaziEventMap Map of events to lua callbacks
---@field _id string ID of the yazi instance
local YaziIpcClient = {}
YaziIpcClient.__index = YaziIpcClient
YaziIpcClient.__is_class = true

function YaziIpcClient.new()
  local obj = setmetatable({
    _event_map = EventMap.new(),
  }, YaziIpcClient)

  return obj
end

-- Send a remote message to a running yazi instance
--
---@param payload any
function YaziIpcClient:send(payload)
  local cmd = ("ya pub nvim %s --json %s"):format(
    self._id,
    vim.fn.shellescape(vim.json.encode(payload))
  )
  terminal_utils.system_unsafe(cmd)
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
  local receiver_id = parts[2]
  local sender_id_or_severity = parts[3]
  local body = vim.json.decode(parts[4])

  if not event or not receiver_id or not sender_id_or_severity or not body then
    vim.error("Invalid message format: ", message)
    return
  end

  if not self._id then self._id = receiver_id end
  if receiver_id ~= self._id then
    vim.error("Receiver ID does not match: ", receiver_id, self._id)
  end

  if event == "nvim" then
    if not type(body.type) == "string" then
      vim.error("Invalid body for custom event: ", body)
      return
    end
    event = body.type
  end

  vim.info(event, body)

  local callbacks = self._event_map:get(event)
  for _, callback in ipairs(callbacks) do
    callback(body)
  end
end

return YaziIpcClient
