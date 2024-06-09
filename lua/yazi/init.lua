local uuid_utils = require("utils.uuid")
local opts_utils = require("utils.opts")
local yazi_setup = require("yazi.config").setup
local config = require("yazi.config").config
local tbl_utils = require("utils.table")
local IpcClient = require("yazi.ipc-client")
local CallbackMap = require("yazi.callback-map")
local terminal_utils = require("utils.terminal")

local M = {}

---@alias YaziControllerId string
---@alias YaziUIHooks { show: function, hide: function, focus: function, destroy: function }

M.setup = yazi_setup

-- Generic classes still WIP
-- https://github.com/LuaLS/lua-language-server/issues/1861
--
---@class YaziController
---@field _id YaziControllerId The id of the controller
---@field focus? any The currently focused entry
---@field _ipc_client YaziIpcClient The ipc client
---@field _extra_args? ShellOpts Extra arguments to pass to yazi
---@field _ui_hooks? YaziUIHooks UI hooks
---@field _extra_env_vars? ShellOpts Extra environment variables to pass to yazi
---@field _prev_win? number Previous window before opening yazi
---@field _on_exited_subscribers YaziCallbackMap Map of subscribers of the exit event
---@field _started boolean Whether the controller has started
---@field _exited boolean Whether the controller has exited
local Controller = {}
Controller.__index = Controller
Controller.__is_class = true

-- Map of controller ID to controller.
-- A singleton.
--
---@class YaziControllerMap
---@field [YaziControllerId] YaziController
local ControllerMap = {}

-- Check if controller exists
--
---@param controller_id YaziControllerId
---@return boolean
function ControllerMap.exists(controller_id)
  return ControllerMap[controller_id] ~= nil
end

M.Controller = Controller

-- Create controller
--
---@alias YaziCreateControllerOptions { name: string, extra_args?: ShellOpts, extra_env_vars?: ShellOpts, path?: string }
---@param opts? YaziCreateControllerOptions
---@return YaziController
function Controller.new(opts)
  opts = opts_utils.extend({
    path = vim.fn.getcwd(),
  }, opts)
  ---@cast opts YaziCreateControllerOptions

  if not vim.fn.executable("yazi") == 1 then error("yazi is not installed") end

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
  ControllerMap[controller_id] = controller

  return controller
end

-- Destroy controller
--
---@param controller_id YaziControllerId
function ControllerMap.destroy(controller_id)
  local controller = ControllerMap[controller_id]
  if not controller then error("Controller not found") end

  controller._ipc_client:destroy()
  controller._ui_hooks:destroy()

  ControllerMap[controller_id] = nil
end

-- Destroy controller
--
---@param self YaziController
function Controller:_destroy() ControllerMap.destroy(self._id) end

-- Retrieve prev window (before opening yazi)
--
---@return number
function Controller:prev_win() return self._prev_win end

-- Retrieve prev buffer (before opening yazi)
--
---@return number
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
---@return number
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
end

-- Hide the UI
function Controller:hide()
  if not self._ui_hooks then
    error("UI hooks missing. Please first set them up")
  end

  self._ui_hooks.hide()
end

---@param hooks YaziUIHooks
function Controller:set_ui_hooks(hooks) self._ui_hooks = hooks end

-- Start the yazi process
function Controller:start()
  local args = {}
  args =
    tbl_utils.tbl_extend({ mode = "error" }, args, config.default_extra_args)
  args = tbl_utils.tbl_extend({ mode = "error" }, args, self._extra_args)

  local command = "yazi " .. terminal_utils.shell_opts_tostring(args)

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

  vim.fn.termopen(command, {
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
    on_stdout = function(job_id, ...)
      -- print(vim.inspect({ ... }))
    end,
    on_stderr = function(job_id, ...)
      -- error(vim.inspect({ ... }))
    end,
  })
  self._started = true
end

-- Send an action to yazi to execute
--
---@param action string
function Controller:execute(action) return self._ipc_client:execute(action) end

-- Subscribe to yazi event
--
---@param event string
---@param callback YaziCallback
function Controller:subscribe(event, callback)
  return self._ipc_client:subscribe(event, callback)
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
