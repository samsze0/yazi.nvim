local NuiLayout = require("nui.layout")
local MainPopup = require("yazi.layout.popup").MainPopup
local SidePopup = require("yazi.layout.popup").SidePopup
local HelpPopup = require("yazi.layout.popup").HelpPopup
local config = require("yazi.config").config
local opts_utils = require("utils.opts")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

---@type nui_layout_options
local layout_opts = {
  position = "50%",
  relative = "editor",
  size = {
    width = "95%",
    height = "95%",
  },
}

---@class YaziLayout: NuiLayout
---@field maximised_popup? YaziPopup
---@field layout_config { default: NuiLayout.Box }
---@field main_popup YaziMainPopup
---@field help_popup YaziHelpPopup
local Layout = {}
Layout.__index = Layout
Layout.__is_class = true
setmetatable(Layout, { __index = NuiLayout })

---@param box NuiLayout.Box
---@param opts? { layout_opts?: nui_layout_options }
---@return YaziLayout
function Layout.new(box, opts)
  opts = opts_utils.deep_extend({
    layout_opts = layout_opts,
  }, opts)

  local obj = NuiLayout(opts.layout_opts, box)
  setmetatable(obj, Layout)
  ---@cast obj YaziLayout

  obj.maximised_popup = nil

  return obj
end

function Layout:setup_keymaps()
  self.main_popup:map(config.keymaps.show_help, "Show help", function()
    self.help_popup:show()
    self.help_popup:focus()
  end)

  self.help_popup:map(
    "n",
    config.keymaps.hide_help,
    function() self.help_popup:hide() end
  )
end

-- TODO: move isinstance function to oop utils
local function is_instance(o, class)
  while o do
    o = getmetatable(o)
    if class == o then return true end
  end
  return false
end

---@param popup YaziPopup
---@param box NuiLayout.Box
function Layout:_setup_popup_maximised_keymaps(popup, box)
  local fn = function()
    if self.maximised_popup == popup then
      self:update(self.layout_config.default)
      self.maximised_popup = nil
    else
      self:update(box)
      self.maximised_popup = popup
    end
  end  

  if is_instance(popup, MainPopup) then
    ---@cast popup YaziMainPopup
    popup:map(config.keymaps.toggle_maximise, "Toggle maximise", fn)
  else
    popup:map("n", config.keymaps.toggle_maximise, fn)
  end
end

---@class YaziSinglePaneLayout: YaziLayout
---@field main_popup YaziMainPopup
---@field help_popup YaziHelpPopup
local SinglePaneLayout = {}
SinglePaneLayout.__index = SinglePaneLayout
SinglePaneLayout.__is_class = true
setmetatable(SinglePaneLayout, { __index = Layout })

---@param opts? { main_popup?: YaziMainPopup, help_popup?: YaziSidePopup, extra_layout_opts?: nui_layout_options, layout_config?: { default?: fun(main_popup: YaziMainPopup, help_popup: YaziHelpPopup): NuiLayout.Box } }
---@return YaziLayout
function SinglePaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "100%" }),
        }, {})
      end,
    }
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(opts.main_popup, opts.help_popup),
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, SinglePaneLayout)
  ---@cast obj YaziSinglePaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.help_popup = opts.help_popup

  return obj
end

function SinglePaneLayout:setup_keymaps()
  Layout.setup_keymaps(self)
end

---@class YaziDualPaneLayout: YaziLayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: NuiLayout.Box } }
---@field side_popup YaziSidePopup
local DualPaneLayout = {}
DualPaneLayout.__index = DualPaneLayout
DualPaneLayout.__is_class = true
setmetatable(DualPaneLayout, { __index = Layout })

---@param opts? { main_popup?: YaziMainPopup, side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup, extra_layout_opts?: nui_layout_options, layout_config?: { default?: (fun(main_popup: YaziMainPopup, side_popup: YaziSidePopup, help_popup: YaziHelpPopup): NuiLayout.Box), maximised?: { main?: (fun(main_popup: YaziMainPopup, side_popup: YaziSidePopup, help_popup: YaziHelpPopup): NuiLayout.Box), side?: (fun(main_popup: YaziMainPopup, side_popup: YaziSidePopup, help_popup: YaziHelpPopup): NuiLayout.Box) } } }
---@return YaziDualPaneLayout
function DualPaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popup, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "50%" }),
          NuiLayout.Box(side_popup, { size = "50%" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popup, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = function(main_popup, side_popup, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(side_popup, { size = "100%" }),
          }, {})
        end,
      },
    }
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  if not opts.side_popup then opts.side_popup = SidePopup.new() end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popup,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popup,
        opts.help_popup
      ),
      side = opts.layout_config.maximised.side(
        opts.main_popup,
        opts.side_popup,
        opts.help_popup
      ),
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, DualPaneLayout)
  ---@cast obj YaziDualPaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popup = opts.side_popup
  obj.help_popup = opts.help_popup

  return obj
end

function DualPaneLayout:setup_keymaps()
  Layout.setup_keymaps(self)

  self.main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popup:focus() end
  )

  self.side_popup:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )

  self:_setup_popup_maximised_keymaps(
    self.main_popup,
    self.layout_config.maximised.main
  )
  self:_setup_popup_maximised_keymaps(
    self.side_popup,
    self.layout_config.maximised.side
  )
end

---@class YaziTriplePaneLayout: YaziLayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: { left: NuiLayout.Box, right: NuiLayout.Box } } }
---@field side_popups { left: YaziSidePopup, right: YaziSidePopup }
local TriplePaneLayout = {}
TriplePaneLayout.__index = TriplePaneLayout
TriplePaneLayout.__is_class = true
setmetatable(TriplePaneLayout, { __index = Layout })

---@param opts? { main_popup?: YaziMainPopup, side_popups?: { left: YaziSidePopup, right: YaziSidePopup }, help_popup?: YaziHelpPopup, extra_layout_opts?: nui_layout_options, layout_config?: { default?: (fun(main_popup: YaziMainPopup, side_popups: { left: YaziSidePopup, right: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), maximised?: { main?: (fun(main_popup: YaziMainPopup, side_popups: { left: YaziSidePopup, right: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), side?: { left?: (fun(main_popup: YaziMainPopup, side_popups: { left: YaziSidePopup, right: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), right?: (fun(main_popup: YaziMainPopup, side_popups: { left: YaziSidePopup, right: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box) } } } }
---@return YaziTriplePaneLayout
function TriplePaneLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popups, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "30%" }),
          NuiLayout.Box(side_popups.left, { size = "35%" }),
          NuiLayout.Box(side_popups.right, { size = "35%" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popups, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = {
          left = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.left, { size = "100%" }),
            }, {})
          end,
          right = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.right, { size = "100%" }),
            }, {})
          end,
        },
      },
    }
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  -- TODO
  if not opts.side_popups then
    opts.side_popups = {
      left = SidePopup.new(),
      right = SidePopup.new(),
    }
  end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popups,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popups,
        opts.help_popup
      ),
      side = {
        left = opts.layout_config.maximised.side.left(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
        right = opts.layout_config.maximised.side.right(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
      },
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, TriplePaneLayout)
  ---@cast obj YaziTriplePaneLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups
  obj.help_popup = opts.help_popup

  return obj
end

function TriplePaneLayout:setup_keymaps()
  Layout.setup_keymaps(self)

  self.main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popups.left:focus() end
  )

  self.side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )

  self.side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.right,
    function() self.side_popups.right:focus() end
  )

  self.side_popups.right:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() self.side_popups.left:focus() end
  )

  self:_setup_popup_maximised_keymaps(
    self.main_popup,
    self.layout_config.maximised.main
  )
  self:_setup_popup_maximised_keymaps(
    self.side_popups.left,
    self.layout_config.maximised.side.left
  )
  self:_setup_popup_maximised_keymaps(
    self.side_popups.right,
    self.layout_config.maximised.side.right
  )
end

---@class YaziTriplePane2ColumnLayout: YaziLayout
---@field layout_config { default?: NuiLayout.Box, maximised?: { main: NuiLayout.Box, side: { top: NuiLayout.Box, bottom: NuiLayout.Box } } }
---@field side_popups { top: YaziSidePopup, bottom: YaziSidePopup }
local TriplePane2ColumnLayout = {}
TriplePane2ColumnLayout.__index = TriplePane2ColumnLayout
TriplePane2ColumnLayout.__is_class = true
setmetatable(TriplePane2ColumnLayout, { __index = Layout })

---@param opts? { main_popup?: YaziMainPopup, side_popups?: { top: YaziSidePopup, bottom: YaziSidePopup }, help_popup?: YaziHelpPopup, extra_layout_opts?: nui_layout_options, layout_config?: { default?: (fun(main_popup: YaziMainPopup, side_popups: { top: YaziSidePopup, bottom: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), maximised?: { main?: (fun(main_popup: YaziMainPopup, side_popups: { top: YaziSidePopup, bottom: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), side?: { top?: (fun(main_popup: YaziMainPopup, side_popups: { top: YaziSidePopup, bottom: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box), bottom?: (fun(main_popup: YaziMainPopup, side_popups: { top: YaziSidePopup, bottom: YaziSidePopup }, help_popup: YaziHelpPopup): NuiLayout.Box) } } } }
---@return YaziTriplePane2ColumnLayout
function TriplePane2ColumnLayout.new(opts)
  opts = opts_utils.deep_extend({
    layout_config = {
      default = function(main_popup, side_popups, help_popup)
        return NuiLayout.Box({
          NuiLayout.Box(main_popup, { size = "50%" }),
          NuiLayout.Box({
            NuiLayout.Box(side_popups.top, { size = "20%" }),
            NuiLayout.Box(side_popups.bottom, { grow = 1 }),
          }, { size = "50%", dir = "col" }),
        }, { dir = "row" })
      end,
      maximised = {
        main = function(main_popup, side_popups, help_popup)
          return NuiLayout.Box({
            NuiLayout.Box(main_popup, { size = "100%" }),
          }, {})
        end,
        side = {
          top = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.top, { size = "100%" }),
            }, {})
          end,
          bottom = function(main_popup, side_popups, help_popup)
            return NuiLayout.Box({
              NuiLayout.Box(side_popups.bottom, { size = "100%" }),
            }, {})
          end,
        },
      },
    }
  }, opts)

  if not opts.main_popup then opts.main_popup = MainPopup.new() end
  -- TODO
  if not opts.side_popups then
    opts.side_popups = {
      top = SidePopup.new(),
      bottom = SidePopup.new(),
    }
  end
  if not opts.help_popup then opts.help_popup = HelpPopup.new() end

  local layout_config = {
    default = opts.layout_config.default(
      opts.main_popup,
      opts.side_popups,
      opts.help_popup
    ),
    maximised = {
      main = opts.layout_config.maximised.main(
        opts.main_popup,
        opts.side_popups,
        opts.help_popup
      ),
      side = {
        top = opts.layout_config.maximised.side.top(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
        bottom = opts.layout_config.maximised.side.bottom(
          opts.main_popup,
          opts.side_popups,
          opts.help_popup
        ),
      },
    },
  }

  local obj = Layout.new(layout_config.default, opts)
  setmetatable(obj, TriplePane2ColumnLayout)
  ---@cast obj YaziTriplePane2ColumnLayout

  obj.layout_config = layout_config
  obj.main_popup = opts.main_popup
  obj.side_popups = opts.side_popups
  obj.help_popup = opts.help_popup

  return obj
end

function TriplePane2ColumnLayout:setup_keymaps()
  Layout.setup_keymaps(self)

  self.main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() self.side_popups.top:focus() end
  )

  self.side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() self.main_popup:focus() end
  )

  self.side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.bottom,
    function() self.side_popups.bottom:focus() end
  )

  self.side_popups.bottom:map(
    "n",
    config.keymaps.move_to_pane.top,
    function() self.side_popups.top:focus() end
  )

  self:_setup_popup_maximised_keymaps(
    self.main_popup,
    self.layout_config.maximised.main
  )
  self:_setup_popup_maximised_keymaps(
    self.side_popups.top,
    self.layout_config.maximised.side.top
  )
  self:_setup_popup_maximised_keymaps(
    self.side_popups.bottom,
    self.layout_config.maximised.side.bottom
  )
end

return {
  AbstractLayout = Layout,
  SinglePaneLayout = SinglePaneLayout,
  DualPaneLayout = DualPaneLayout,
  TriplePaneLayout = TriplePaneLayout,
  TriplePane2ColumnLayout = TriplePane2ColumnLayout,
}
