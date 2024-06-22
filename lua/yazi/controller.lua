local uuid_utils = require("utils.uuid")
local opts_utils = require("utils.opts")
local config = require("yazi.config").config
local tbl_utils = require("utils.table")
local CallbackMap = require("yazi.callback-map")
local IpcClient = require("yazi.ipc-client")
local terminal_utils = require("utils.terminal")
local str_utils = require("utils.string")

local M = {}

---@alias YaziControllerId string
---@alias YaziUIHooks { show: function, hide: function, focus: function, destroy: function }
---@alias YaziFocusedEntry { url: string }

---@class YaziController
---@field _id YaziControllerId The id of the controller
---@field focus? YaziFocusedEntry The currently focused entry
---@field _ipc_client YaziIpcClient The ipc client
---@field _extra_args? ShellOpts Extra arguments to pass to yazi
---@field _ui_hooks? YaziUIHooks UI hooks
---@field _extra_env_vars? ShellOpts Extra environment variables to pass to yazi
---@field _prev_win? integer Previous window before opening yazi
---@field _on_exited_subscribers YaziCallbackMap Map of subscribers of the exit event
---@field _started boolean Whether the controller has started
---@field _exited boolean Whether the controller has exited
---@field _job_id string Job ID of the yazi process
---@field _events_reader_job_id string Job ID of the events reader process
local Controller = {}
Controller.__index = Controller
Controller.__is_class = true

-- Index of active controllers
-- A singleton.
--
---@class YaziControllersIndex
---@field _id_map table<YaziControllerId, YaziController>
---@field most_recent? YaziController
local ControllersIndex = {
  _id_map = {},
  most_recent = nil,
}
ControllersIndex.__index = ControllersIndex
ControllersIndex.__is_class = true

-- Retrieve a controller by its ID
--
---@param id YaziControllerId
---@return YaziController | nil
function ControllersIndex.get(id) return ControllersIndex._id_map[id] end

-- Remove a controller by its ID
--
---@param id YaziControllerId
function ControllersIndex.remove(id) ControllersIndex._id_map[id] = nil end

-- Add a controller to the index
--
---@param controller YaziController
function ControllersIndex.add(controller)
  ControllersIndex._id_map[controller._id] = controller
end

M.ControllersIndex = ControllersIndex

M.Controller = Controller

-- Create controller
--
---@alias YaziCreateControllerOptions { extra_args?: ShellOpts, extra_env_vars?: ShellOpts, path?: string }
---@param opts? YaziCreateControllerOptions
---@return YaziController
function Controller.new(opts)
  opts = opts_utils.extend({
    path = vim.fn.getcwd(),
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

  local controller_id = uuid_utils.v4()
  local controller = {
    _id = controller_id,
    focus = nil,
    _ipc_client = IpcClient.new(),
    _extra_args = opts.extra_args,
    _ui_hooks = nil,
    _extra_env_vars = opts.extra_env_vars,
    _on_exited_subscribers = CallbackMap.new(),
    _prev_win = vim.api.nvim_get_current_win(),
    _started = false,
    _exited = false,
  }
  setmetatable(controller, Controller)
  ControllersIndex.add(controller)

  ---@cast controller YaziController

  controller:on_hover(function(payload) controller.focus = payload end)

  return controller
end

-- Destroy controller
--
---@param self YaziController
function Controller:_destroy()
  self._ipc_client:destroy()
  self._ui_hooks:destroy()

  ControllersIndex.remove(self._id)
  if ControllersIndex.most_recent == self then
    ControllersIndex.most_recent = nil
  end
end

-- Retrieve prev window (before opening yazi)
--
---@return integer
function Controller:prev_win() return self._prev_win end

-- Retrieve prev buffer (before opening yazi)
--
---@return integer
function Controller:prev_buf()
  local win = self:prev_win()
  return vim.api.nvim_win_get_buf(win)
end

-- Retrieve the filepath of the file opened in prev buffer (before opening yazi)
--
---@return string
function Controller:prev_filepath()
  return vim.api.nvim_buf_get_name(self:prev_buf())
end

-- Retrieve prev tab (before opening yazi)
--
---@return integer
function Controller:prev_tab()
  return vim.api.nvim_win_get_tabpage(self:prev_win())
end

-- Show the UI and focus on it
function Controller:show_and_focus()
  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.show()
  self._ui_hooks.focus()

  ControllersIndex.most_recent = self
end

-- Hide the UI
--
---@param opts? { restore_focus?: boolean }
function Controller:hide(opts)
  opts = opts_utils.extend({ restore_focus = true }, opts)

  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.hide()

  if opts.restore_focus then vim.api.nvim_set_current_win(self:prev_win()) end
end

---@param hooks YaziUIHooks
function Controller:set_ui_hooks(hooks) self._ui_hooks = hooks end

-- Start the yazi process
function Controller:start()
  local args = {
    ["--local-events"] = table.concat({
      "cd",
      "hover",
      "rename",
      "bulk",
      "yank",
      "move",
      "trash",
      "delete",
    }, ","),
    ["--remote-events"] = "nvim", -- make yazi accepts remote events with name "nvim"
  }
  args =
    tbl_utils.tbl_extend({ mode = "error" }, args, config.default_extra_args)
  args = tbl_utils.tbl_extend({ mode = "error" }, args, self._extra_args)

  local events_destination = "/tmp/yazi.nvim-" .. self._id
  local command = "yazi "
    .. terminal_utils.shell_opts_tostring(args)
    .. " > "
    .. events_destination

  local env_vars = {}
  env_vars = tbl_utils.tbl_extend(
    { mode = "error" },
    env_vars,
    config.default_extra_env_vars
  )
  env_vars =
    tbl_utils.tbl_extend({ mode = "error" }, env_vars, self._extra_env_vars)

  command = ("%s %s"):format(
    terminal_utils.shell_opts_tostring(env_vars),
    command
  )

  self:show_and_focus()

  terminal_utils.system_unsafe("touch " .. events_destination)

  local events_reader_job_id =
    vim.fn.jobstart("tail -f " .. events_destination, {
      on_stdout = function(job_id, message)
        self._ipc_client:on_message(table.concat(message, "\n"))
      end,
      on_stderr = function(job_id, message)
        vim.error("Error reading yazi events: ", table.concat(message, "\n"))
      end,
    })
  if events_reader_job_id == 0 or events_reader_job_id == -1 then
    error("Failed to start yazi events reader")
  end
  self._events_reader_job_id = events_reader_job_id

  local job_id = vim.fn.termopen(command, {
    on_exit = function(job_id, code, event)
      self._exited = true
      self._on_exited_subscribers:invoke_all()

      if code == 0 then
        -- Pass
      else
        error("Unexpected exit code: " .. code)
      end

      self:_destroy()
    end,
    on_stdout = function(job_id, ...) end,
    on_stderr = function(job_id, ...) end,
  })
  if job_id == 0 or job_id == -1 then error("Failed to start yazi") end
  self._job_id = job_id

  self._started = true
end

-- Send a message to the running yazi instance
--
---@param payload any
function Controller:send(payload) return self._ipc_client:send(payload) end

-- Subscribe to yazi event
--
---@param event string
---@param callback YaziCallback
---@return fun(): nil Unsubscribe
function Controller:subscribe(event, callback)
  return self._ipc_client:subscribe(event, callback)
end

-- Subscribe to the "cd" event
--
---@alias YaziCdEventPayload { tab: string, url: string }
---@param callback fun(payload: YaziCdEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_cd(callback) return self:subscribe("cd", callback) end

-- Subscribe to the "hover" event
--
---@alias YaziHoverEventPayload { tab: string, url: string }
---@param callback fun(payload: YaziHoverEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_hover(callback) return self:subscribe("hover", callback) end

-- Subscribe to the "rename" event
--
---@alias YaziRenameEventPayload { tab: string, from: string, to: string }
---@param callback fun(payload: YaziRenameEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_rename(callback)
  return self:subscribe("rename", callback)
end

-- Subscribe to the "bulk" event
--
---@alias YaziBulkEventPayload { changes: table<string, string> }
---@param callback fun(payload: YaziBulkEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_bulk(callback) return self:subscribe("bulk", callback) end

-- Subscribe to the "yank" event
--
---@alias YaziYankEventPayload { cut: boolean, urls: string[] }
---@param callback fun(payload: YaziYankEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_yank(callback) return self:subscribe("yank", callback) end

-- Subscribe to the "move" event
--
---@alias YaziMoveEventPayload { items: ({ from: string, to: string })[] }
---@param callback fun(payload: YaziMoveEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_move(callback) return self:subscribe("move", callback) end

-- Subscribe to the "trash" event
--
---@alias YaziTrashEventPayload { urls: string[] }
---@param callback fun(payload: YaziTrashEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_trash(callback) return self:subscribe("trash", callback) end

-- Subscribe to the "delete" event
--
---@alias YaziDeleteEventPayload { urls: string[] }
---@param callback fun(payload: YaziDeleteEventPayload)
---@return fun(): nil Unsubscribe
function Controller:on_delete(callback)
  return self:subscribe("delete", callback)
end

function Controller:started() return self._started end

function Controller:exited() return self._exited end

-- Subscribe to the event "exited"
--
---@param callback fun()
---@return fun() Unsubscribe
function Controller:on_exited(callback)
  return self._on_exited_subscribers:add_and_return_remove_fn(callback)
end

return M
