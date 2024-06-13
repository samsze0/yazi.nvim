local NuiPopup = require("nui.popup")
local NuiEvent = require("nui.utils.autocmd").event
local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")

---@type nui_popup_options
local base_popup_config = {
  focusable = true,
  border = {
    style = "rounded",
  },
  buf_options = {
    modifiable = true,
  },
  win_options = {
    winblend = 0,
    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
    number = false,
    wrap = false,
  },
}

---@type nui_popup_options
local base_help_popup_config = {
  win_options = {
    wrap = true,
  },
  relative = "editor",
  position = "50%",
  size = {
    width = 0.75,
    height = 0.75,
  },
  zindex = 50,
}
base_help_popup_config =
  opts_utils.deep_extend(base_popup_config, base_help_popup_config)
---@cast base_help_popup_config nui_popup_options

---@class YaziMainPopup: NuiPopup
---@field _yazi_keymaps table<string, string> Mappings of key to name (of the handler)
---@field _maximised boolean
local MainPopup = {}
MainPopup.__index = MainPopup
MainPopup.__is_class = true
setmetatable(MainPopup, { __index = NuiPopup })

---@param config? nui_popup_options
---@return YaziMainPopup
function MainPopup.new(config)
  config = opts_utils.deep_extend(base_popup_config, {
    enter = false, -- This can mute BufEnter event
    buf_options = {
      modifiable = false,
      filetype = "yazi",
    },
    win_options = {},
  }, config)

  local obj = NuiPopup(config)
  setmetatable(obj, MainPopup)
  ---@cast obj YaziMainPopup

  obj._yazi_keymaps = {}
  obj._maximised = false

  obj:on(NuiEvent.BufEnter, function() vim.cmd("startinsert!") end)

  return obj
end

function MainPopup:focus() vim.api.nvim_set_current_win(self.winid) end

---@return boolean
function MainPopup:maximised() return self._maximised end

---@param maximised boolean
function MainPopup:set_maximised(maximised) self._maximised = maximised end

---@param key string
---@param name? string Purpose of the handler
---@param handler fun()
---@param opts? { force?: boolean }
function MainPopup:map(key, name, handler, opts)
  opts = opts_utils.extend({ force = false }, opts)
  name = name or "?"

  if self._yazi_keymaps[key] and not opts.force then
    error(
      ("Key %s is already mapped to %s"):format(key, self._yazi_keymaps[key])
    )
    return
  end
  NuiPopup.map(self, "t", key, handler)
  self._yazi_keymaps[key] = name
end

-- Get current mappings of keys to handler names
---@return table<string, string>
function MainPopup:keymaps() return self._yazi_keymaps end

---@param popup YaziSidePopup
---@param key string
---@param name? string Purpose of the handler
---@param opts? { force?: boolean }
function MainPopup:map_remote(popup, name, key, opts)
  self:map(key, name, function()
    -- Looks like window doesn't get redrawn if we don't switch to it
    -- vim.api.nvim_win_call(popup.winid, function() vim.api.nvim_input(key) end)

    vim.api.nvim_set_current_win(popup.winid)
    vim.api.nvim_input(key)
    -- Because nvim_input is non-blocking, so we need to schedule the switch such that the switch happens after the input
    vim.schedule(function() vim.api.nvim_set_current_win(self.winid) end)
  end, opts)
end

---@class YaziSidePopup: NuiPopup
---@field _maximised boolean
local SidePopup = {}
SidePopup.__index = SidePopup
SidePopup.__is_class = true
setmetatable(SidePopup, { __index = NuiPopup })

---@param config? nui_popup_options
---@return YaziSidePopup
function SidePopup.new(config)
  config = opts_utils.deep_extend(base_popup_config, {}, config)

  local obj = NuiPopup(config)
  setmetatable(obj, SidePopup)
  ---@cast obj YaziSidePopup

  obj._maximised = false

  return obj
end

function SidePopup:focus() vim.api.nvim_set_current_win(self.winid) end

---@return boolean
function SidePopup:maximised() return self._maximised end

---@param maximised boolean
function SidePopup:set_maximised(maximised) self._maximised = maximised end

---@return string[]
function SidePopup:get_lines()
  return vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
end

---@param lines string[]
---@param opts? { cursor_pos?: number[] }
function SidePopup:set_lines(lines, opts)
  opts = opts_utils.extend({}, opts)

  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
  if opts.cursor_pos then
    vim.api.nvim_win_set_cursor(self.winid, opts.cursor_pos or { 1, 0 })
    vim.api.nvim_win_call(self.winid, function() vim.cmd("normal! zz") end)
  end
end

---@param path string
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_file_content(path, opts)
  opts = opts_utils.extend({}, opts)

  if vim.fn.filereadable(path) ~= 1 then
    self:set_lines({ "File not readable, or doesnt exist" })
    return
  end

  local file_mime, status, _ = terminal_utils.system("file --mime " .. path)
  if status ~= 0 then
    self:set_lines({ "Cannot determine if file is binary" })
    return
  end
  ---@cast file_mime string

  local is_binary = file_mime:match("charset=binary")

  if is_binary then
    self:set_lines({ "No preview available for binary file" })
    return
  end

  local lines = vim.fn.readfile(path)
  local filename = vim.fn.fnamemodify(path, ":t")
  local filetype = vim.filetype.match({
    filename = filename,
    contents = lines,
  })
  self:set_lines(lines, { cursor_pos = opts.cursor_pos })
  vim.bo[self.bufnr].filetype = filetype or ""
end

---@param buf number
---@param opts? { cursor_pos?: number[] }
function SidePopup:show_buf_content(buf, opts)
  opts = opts or {}

  local path = vim.api.nvim_buf_get_name(buf)
  self:show_file_content(path, { cursor_pos = opts.cursor_pos })
end

---@class YaziHelpPopup: NuiPopup
---@field _visible boolean
local HelpPopup = {}
HelpPopup.__index = HelpPopup
HelpPopup.__is_class = true
setmetatable(HelpPopup, { __index = NuiPopup })

---@param config? nui_popup_options
---@return YaziHelpPopup
function HelpPopup.new(config)
  config = opts_utils.deep_extend(base_help_popup_config, {}, config)

  local obj = NuiPopup(config)
  setmetatable(obj, HelpPopup)
  ---@cast obj YaziHelpPopup

  return obj
end

function HelpPopup:focus() vim.api.nvim_set_current_win(self.winid) end

---@return boolean
function HelpPopup:is_visible() return self._visible end

---@param visible boolean
function HelpPopup:set_visible(visible) self._visible = visible end

---@param lines string[]
function HelpPopup:set_lines(lines)
  vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, lines)
end

---@param keymaps table<string, string>
function HelpPopup:set_keymaps(keymaps)
  local items = tbl_utils.map(
    keymaps,
    function(key, name) return name .. " : " .. key end
  )
  items = tbl_utils.sort(items, function(a, b) return a < b end)
  self:set_lines(items)
end

return {
  MainPopup = MainPopup,
  SidePopup = SidePopup,
  HelpPopup = HelpPopup,
}
