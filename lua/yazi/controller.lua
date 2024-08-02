local Controller = require("tui.controller")
local ControllerMap = require("tui.controller-map")
local uuid_utils = require("utils.uuid")
local opts_utils = require("utils.opts")
local config = require("yazi.config").value
local tbl_utils = require("utils.table")
local CallbackMap = require("tui.callback-map")
local IpcClient = require("yazi.ipc-client")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")
local uv_utils = require("utils.uv")

local _info = config.notifier.info
---@cast _info -nil
local _warn = config.notifier.warn
---@cast _warn -nil
local _error = config.notifier.error
---@cast _error -nil

---@alias YaziFocusedEntry { url: string }

---@class YaziController: TUIController
---@field focus? YaziFocusedEntry The currently focused entry
---@field preview_visible? boolean Whether the preview pane is visible. Value is nil if unknown
---@field _ipc_client YaziIpcClient The ipc client
---@field _events_reader_job_id string Job ID of the events reader process
local YaziController = {}
YaziController.__index = YaziController
YaziController.__is_class = true
setmetatable(YaziController, { __index = Controller })

-- Index of active controllers
-- A singleton.
local yazi_controller_map = ControllerMap.new()

---@class YaziCreateControllerOptions: TUICreateControllerOptions

-- Create controller
--
---@param opts? YaziCreateControllerOptions
---@return YaziController
function YaziController.new(opts)
  opts = opts_utils.extend({
    config = require("yazi.config"),
    index = yazi_controller_map,
  }, opts)
  ---@cast opts YaziCreateControllerOptions

  if not vim.fn.executable("yazi") == 1 then error("yazi is not installed") end
  if not vim.fn.executable("ya") == 1 then
    error("yazi command-line tool is not installed")
  end

  local version = terminal_utils.system_unsafe("yazi --version")
  local match = version:match("^Yazi %d+%.%d+%.%d+")
  ---@cast match string
  if #match == 0 then error("fail to get yazi version") end
  match = match:sub(("Yazi "):len() + 1)
  local version = str_utils.split(match, {
    sep = "%.",
  })
  local major = version[1]
  local minor = version[2]
  local patch = version[3]
  if not major or not minor or not patch then
    error("fail to get yazi version")
  end
  if major ~= "0" or minor ~= "2" or patch ~= "5" then
    error("only version 0.2.5 is supported")
  end

  local obj = Controller.new(opts)
  ---@cast obj YaziController

  obj._ipc_client = IpcClient.new()

  setmetatable(obj, YaziController)

  obj:on_preview_visibility(
    function(payload) obj.preview_visible = payload.visible end
  )
  obj:on_hover(function(payload) obj.focus = payload end)

  return obj
end

-- Destroy controller
--
---@param self YaziController
function YaziController:_destroy() Controller._destroy(self) end

-- Start the yazi process
function YaziController:start()
  local args = self:_args_extend({
    ["--local-events"] = table.concat({
      "cd",
      "hover",
      "rename",
      "bulk",
      "yank",
      "move",
      "trash",
      "delete",

      -- Custom events
      "to-nvim",
      "preview-visibility",
    }, ","),
    ["--remote-events"] = "from-nvim", -- make yazi accepts remote events of "from-nvim" kind
  })

  local env_vars = self:_env_vars_extend({
    ["NVIM_YAZI"] = 1,
  })

  local events_destination = "/tmp/yazi.nvim-" .. self._id
  terminal_utils.system_unsafe("touch " .. events_destination)

  local command = terminal_utils.shell_opts_tostring(env_vars)
    .. " yazi "
    .. terminal_utils.shell_opts_tostring(args)
    .. " > "
    .. events_destination

  local events_reader_job_id =
    vim.fn.jobstart("tail -f " .. events_destination, {
      on_stdout = function(job_id, messages)
        xpcall(
          function()
            for _, m in ipairs(vim.list_slice(messages, nil, #messages - 1)) do
              self._ipc_client:on_message(m)
            end
          end,
          function(err)
            _error(debug.traceback("Error processing yazi events: " .. err))
          end
        )
      end,
      on_stderr = function(job_id, messages)
        _error("Error reading yazi events: " .. table.concat(messages, "\n"))
      end,
    })
  if events_reader_job_id == 0 or events_reader_job_id == -1 then
    error("Failed to start yazi events reader")
  end
  self._events_reader_job_id = events_reader_job_id

  self:_start({
    command = command,
  })
end

-- Send a message to the running yazi instance
--
---@param payload any
function YaziController:send(payload) return self._ipc_client:send(payload) end

-- Subscribe to yazi event
--
---@param event string
---@param callback YaziCallback
---@return fun(): nil Unsubscribe
function YaziController:subscribe(event, callback)
  return self._ipc_client:subscribe(event, callback)
end

-- Subscribe to the "cd" event
--
---@alias YaziCdEventPayload { tab: string, url: string }
---@param callback fun(payload: YaziCdEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_cd(callback) return self:subscribe("cd", callback) end

-- Subscribe to the "hover" event
--
---@alias YaziHoverEventPayload { tab: string, url: string }
---@param callback fun(payload: YaziHoverEventPayload)
---@param opts? { debounce_ms?: number }
---@return fun(): nil Unsubscribe
function YaziController:on_hover(callback, opts)
  opts = opts_utils.extend({
    debounce_ms = config.hover_event_debounce_ms,
  }, opts)

  local debounced_callback = uv_utils.debounce(
    function(payload) callback(payload) end,
    opts.debounce_ms,
    { run_in_main_loop = true }
  )
  return self:subscribe("hover", debounced_callback)
end

-- Subscribe to the "rename" event
--
---@alias YaziRenameEventPayload { tab: string, from: string, to: string }
---@param callback fun(payload: YaziRenameEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_rename(callback)
  return self:subscribe("rename", callback)
end

-- Subscribe to the "bulk" event
--
---@alias YaziBulkEventPayload { changes: table<string, string> }
---@param callback fun(payload: YaziBulkEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_bulk(callback)
  return self:subscribe("bulk", callback)
end

-- Subscribe to the "yank" event
--
---@alias YaziYankEventPayload { cut: boolean, urls: string[] }
---@param callback fun(payload: YaziYankEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_yank(callback)
  return self:subscribe("yank", callback)
end

-- Subscribe to the "move" event
--
---@alias YaziMoveEventPayload { items: ({ from: string, to: string })[] }
---@param callback fun(payload: YaziMoveEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_move(callback)
  return self:subscribe("move", callback)
end

-- Subscribe to the "trash" event
--
---@alias YaziTrashEventPayload { urls: string[] }
---@param callback fun(payload: YaziTrashEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_trash(callback)
  return self:subscribe("trash", callback)
end

-- Subscribe to the "delete" event
--
---@alias YaziDeleteEventPayload { urls: string[] }
---@param callback fun(payload: YaziDeleteEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_delete(callback)
  return self:subscribe("delete", callback)
end

-- Subscribe to the custom "quit" event
-- Yazi plugin "nvim.yazi" is required for this event
--
---@alias YaziQuitEventPayload { }
---@param callback fun(payload: YaziQuitEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_quit(callback)
  return self:subscribe("quit", callback)
end

-- Subscribe to the custom "open" event
-- Yazi plugin "nvim.yazi" is required for this event
--
---@alias YaziOpenEventPayload { }
---@param callback fun(payload: YaziOpenEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_open(callback)
  return self:subscribe("open", callback)
end

-- Subscribe to the custom "scroll-preview" event
-- Yazi plugin "nvim.yazi" is required for this event
--
---@alias YaziScrollPreviewEventPayload { value: number }
---@param callback fun(payload: YaziScrollPreviewEventPayload)
---@param opts? { debounce_ms?: number }
---@return fun(): nil Unsubscribe
function YaziController:on_scroll_preview(callback, opts)
  opts = opts_utils.extend({
    debounce_ms = config.scroll_preview_event_debounce_ms,
  }, opts)

  local debounced_callback = uv_utils.debounce(
    function(payload) callback(payload) end,
    opts.debounce_ms,
    { run_in_main_loop = true }
  )
  return self:subscribe("scroll-preview", debounced_callback)
end

-- Subscribe to the custom "preview-visibility" event
-- Yazi plugin "nvim.yazi" is required for this event
--
---@alias YaziPreviewVisibilityEventPayload { visible: boolean }
---@param callback fun(payload: YaziPreviewVisibilityEventPayload)
---@return fun(): nil Unsubscribe
function YaziController:on_preview_visibility(callback)
  return self:subscribe("preview-visibility", callback)
end

-- Set the visibility of yazi's preview pane by sending a remote event
-- Yazi plugin "nvim.yazi" is required for this event
--
---@param val boolean
function YaziController:set_preview_visibility(val)
  if self.preview_visible == val then return end
  return self:send({
    type = "preview-visibility",
    value = val and "show" or "hide",
  })
end

-- Toggle the visibility of yazi's preview pane by sending a remote event
-- Yazi plugin "nvim.yazi" is required for this event
function YaziController:toggle_preview_visibility()
  return self:send({ type = "preview-visibility", value = "toggle" })
end

-- Set yazi's current directory to the given path
-- Yazi plugin "nvim.yazi" is required for this event
--
---@param path string
function YaziController:reveal(path)
  -- TODO: add checking for path
  return self:send({ type = "reveal", path = path })
end

return YaziController
