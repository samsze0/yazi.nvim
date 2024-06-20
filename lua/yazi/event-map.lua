local tbl_utils = require("utils.table")
local lang_utils = require("utils.lang")

---@class YaziEventMap
---@field private value table<string, YaziCallback[]>
local EventMap = {}
EventMap.__index = EventMap

---@param base? YaziEventMap
---@return YaziEventMap self
function EventMap.new(base)
  local obj = base or {}
  setmetatable(obj, EventMap)
  obj.value = {}
  return obj
end

-- Add binds to the map
--
---@param binds table<string, YaziCallback | YaziCallback[]>
---@return YaziEventMap self
function EventMap:extend(binds)
  for k, v in pairs(binds) do
    if type(v) == "table" then
      EventMap:append(k, unpack(v))
    else
      EventMap:append(k, v)
    end
  end

  return self
end

-- Add bind(s) to the map
--
---@param event string
---@param binds YaziCallback[]
---@param opts { prepend: boolean }
---@return YaziEventMap self
function EventMap:_add(event, binds, opts)
  lang_utils.switch(type(self.value[event]), {
    ["nil"] = function() self.value[event] = binds end,
    ["table"] = function()
      if opts.prepend then
        self.value[event] = tbl_utils.list_extend(binds, self.value[event])
      else
        self.value[event] = tbl_utils.list_extend(self.value[event], binds)
      end
    end,
  }, function() error("Invalid value") end)
  return self
end

-- Append bind(s) to the map
--
---@param event string
---@vararg YaziCallback
---@return YaziEventMap self
function EventMap:append(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = false })
end

-- Prepend bind(s) to the map
--
---@param event string
---@vararg YaziCallback
---@return YaziEventMap self
function EventMap:prepend(event, ...)
  local binds = { ... }
  return self:_add(event, binds, { prepend = true })
end

-- Get bind(s) from the map by event name
--
---@param event string
---@return YaziCallback[]
function EventMap:get(event)
  local actions = self.value[event]
  if not actions then return {} end
  return actions
end

function EventMap:__tostring()
  return table.concat(
    tbl_utils.map(
      self.value,
      function(ev, actions)
        return ("%s:%s"):format(ev, table.concat(actions, "+"))
      end
    ),
    ","
  )
end

return EventMap
