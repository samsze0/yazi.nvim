local NuiLayout = require("nui.layout")
local MainPopup = require("yazi.layout.popup").MainPopup
local SidePopup = require("yazi.layout.popup").SidePopup
local HelpPopup = require("yazi.layout.popup").HelpPopup
local config = require("yazi.config")
local opts_utils = require("utils.opts")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- TODO: generics on Popup class

---@alias YaziLayoutSinglePaneOptions { main_popup?: YaziMainPopup, help_popup?: YaziHelpPopup }
---@param opts? YaziLayoutSinglePaneOptions
---@return NuiLayout layout, { main: YaziMainPopup, help: YaziHelpPopup } popups
M.single_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = MainPopup.new(),
    help_popup = HelpPopup.new(),
  }, opts)
  ---@cast opts YaziLayoutSinglePaneOptions

  local main_popup = opts.main_popup
  local help_popup = opts.help_popup

  if not main_popup or not help_popup then error("Some popups are missing") end

  local layout_configs = {
    default = NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "100%" }),
    }, {}),
  }

  local layout = NuiLayout({
    position = "50%",
    relative = "editor",
    size = {
      width = "95%",
      height = "95%",
    },
  }, layout_configs.default)

  main_popup:map(config.keymaps.show_help, "Show help", function()
    if not help_popup:is_visible() then
      help_popup:set_visible(true)
      help_popup:mount()
      help_popup:focus()
    end
  end)

  help_popup:map("n", config.keymaps.hide_help, function()
    if help_popup:is_visible() then
      help_popup:set_visible(false)
      help_popup:unmount()
      layout:update(layout_configs.default)
      main_popup:focus()
    end
  end)

  return layout, {
    main = main_popup,
    help = help_popup,
  }
end

---@alias YaziLayoutDualPaneOptions { main_popup?: YaziMainPopup, side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup }
---@param opts? YaziLayoutDualPaneOptions
---@return NuiLayout, { main: YaziMainPopup, side: YaziSidePopup, help: YaziHelpPopup }
M.dual_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = MainPopup.new(),
    side_popup = SidePopup.new(),
    help_popup = HelpPopup.new(),
  }, opts)
  ---@cast opts YaziLayoutDualPaneOptions

  local main_popup = opts.main_popup
  local side_popup = opts.side_popup
  local help_popup = opts.help_popup

  if not main_popup or not side_popup or not help_popup then
    error("Some popups are missing")
  end

  local popups =
    { main = opts.main_popup, side = opts.side_popup, help = opts.help_popup }

  local layout_configs = {
    default = NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box(side_popup, { size = "50%" }),
    }, { dir = "row" }),
    maximised = {
      main = NuiLayout.Box({
        NuiLayout.Box(main_popup, { size = "100%" }),
        NuiLayout.Box(side_popup, { size = "0%" }),
      }, {}),
      side = NuiLayout.Box({
        NuiLayout.Box(main_popup, { size = "0%" }),
        NuiLayout.Box(side_popup, { size = "100%" }),
      }, {}),
    },
  }

  local layout = NuiLayout({
    position = "50%",
    relative = "editor",
    size = {
      width = "95%",
      height = "95%",
    },
  }, layout_configs.default)

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popup.winid) end
  )

  side_popup:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  main_popup:map(config.keymaps.toggle_maximise, "Toggle maximise", function()
    if main_popup:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popup:set_maximised(false)
    else
      layout:update(layout_configs.maximised.main_popup)
      main_popup:set_maximised(true)
      side_popup:set_maximised(false)
    end
  end)

  side_popup:map("n", config.keymaps.toggle_maximise, function()
    if side_popup:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popup:set_maximised(false)
    else
      layout:update(layout_configs.maximised.side)
      main_popup:set_maximised(false)
      side_popup:set_maximised(true)
    end
  end)

  main_popup:map(config.keymaps.show_help, "Show help", function()
    if not help_popup:is_visible() then
      help_popup:set_visible(true)
      help_popup:mount()
      help_popup:focus()
    end
  end)

  help_popup:map("n", config.keymaps.hide_help, function()
    if help_popup:is_visible() then
      help_popup:set_visible(false)
      help_popup:unmount()
      -- Check if main popup is maximised
      if main_popup:maximised() then
        layout:update(layout_configs.maximised.main)
      else
        layout:update(layout_configs.default)
      end
      main_popup:focus()
    end
  end)

  return layout, popups
end

---@alias YaziLayoutTriplePaneOptions { main_popup?: YaziMainPopup, left_side_popup?: YaziSidePopup, right_side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup }
---@param opts? YaziLayoutTriplePaneOptions
---@return NuiLayout layout, { main: YaziMainPopup, side: { left: YaziSidePopup, right: YaziSidePopup }, help: YaziHelpPopup } popups
M.triple_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = MainPopup.new(),
    left_side_popup = SidePopup.new(),
    right_side_popup = SidePopup.new(),
    help_popup = HelpPopup.new(),
  }, opts)
  ---@cast opts YaziLayoutTriplePaneOptions

  local main_popup = opts.main_popup
  local side_popups = {
    left = opts.left_side_popup,
    right = opts.right_side_popup,
  }
  local help_popup = opts.help_popup

  if
    not main_popup
    or not side_popups.left
    or not side_popups.right
    or not help_popup
  then
    error("Some popups are missing")
  end

  local popups = { main = main_popup, side = side_popups, help = help_popup }

  local layout_configs = {
    default = NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "30%" }),
      NuiLayout.Box(side_popups.left, { size = "35%" }),
      NuiLayout.Box(side_popups.right, { size = "35%" }),
    }, { dir = "row" }),
    maximised = {
      main = NuiLayout.Box({
        NuiLayout.Box(main_popup, { size = "100%" }),
      }, {}),
      side = {
        left = NuiLayout.Box({
          NuiLayout.Box(side_popups.left, { size = "100%" }),
        }, {}),
        right = NuiLayout.Box({
          NuiLayout.Box(side_popups.right, { size = "100%" }),
        }, {}),
      },
    },
  }

  local layout = NuiLayout({
    position = "50%",
    relative = "editor",
    size = {
      width = "95%",
      height = "95%",
    },
  }, layout_configs.default)

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popups.left.winid) end
  )

  side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  side_popups.left:map(
    "n",
    config.keymaps.move_to_pane.right,
    function() vim.api.nvim_set_current_win(side_popups.right.winid) end
  )

  side_popups.right:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(side_popups.left.winid) end
  )

  main_popup:map(config.keymaps.toggle_maximise, "Toggle maximise", function()
    if main_popup:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.left:set_maximised(false)
      side_popups.right:set_maximised(false)
    else
      layout:update(layout_configs.maximised.main_popup)
      main_popup:set_maximised(true)
      side_popups.left:set_maximised(false)
      side_popups.right:set_maximised(false)
    end
  end)

  side_popups.left:map("n", config.keymaps.toggle_maximise, function()
    if side_popups.left:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.left:set_maximised(false)
      side_popups.right:set_maximised(false)
    else
      layout:update(layout_configs.maximised.side.left)
      main_popup:set_maximised(false)
      side_popups.left:set_maximised(true)
      side_popups.right:set_maximised(false)
    end
  end)

  side_popups.right:map("n", config.keymaps.toggle_maximise, function()
    if side_popups.right:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.left:set_maximised(false)
      side_popups.right:set_maximised(false)
    else
      layout:update(layout_configs.maximised.side.right)
      main_popup:set_maximised(false)
      side_popups.left:set_maximised(false)
      side_popups.right:set_maximised(true)
    end
  end)

  main_popup:map(config.keymaps.show_help, "Show help", function()
    if not help_popup:is_visible() then
      help_popup:set_visible(true)
      help_popup:mount()
      help_popup:focus()
    end
  end)

  help_popup:map("n", config.keymaps.hide_help, function()
    if help_popup:is_visible() then
      help_popup:set_visible(false)
      help_popup:unmount()
      -- Check if main popup is maximised
      if main_popup:maximised() then
        layout:update(layout_configs.maximised.main)
      else
        layout:update(layout_configs.default)
      end
      main_popup:focus()
    end
  end)

  return layout, popups
end

---@alias YaziLayoutTriplePane2ColumnOptions { main_popup?: YaziMainPopup, top_side_popup?: YaziSidePopup, bottom_side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup }
---@param opts? YaziLayoutTriplePane2ColumnOptions
---@return NuiLayout, { main: YaziMainPopup, side: { top: YaziSidePopup, bottom: YaziSidePopup }, help: YaziHelpPopup }
M.triple_pane_2_column = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = MainPopup.new(),
    top_side_popup = SidePopup.new(),
    bottom_side_popup = SidePopup.new(),
    help_popup = HelpPopup.new(),
  }, opts)
  ---@cast opts YaziLayoutTriplePane2ColumnOptions

  local main_popup = opts.main_popup
  local side_popups = {
    top = opts.top_side_popup,
    bottom = opts.bottom_side_popup,
  }
  local help_popup = opts.help_popup

  if
    not main_popup
    or not side_popups.top
    or not side_popups.bottom
    or not help_popup
  then
    error("Some popups are missing")
  end

  local layout_configs = {
    default = NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box({
        NuiLayout.Box(side_popups.top, { size = "20%" }),
        NuiLayout.Box(side_popups.bottom, { grow = 1 }),
      }, { size = "50%", dir = "col" }),
    }, { dir = "row" }),
    maximised = {
      main = NuiLayout.Box({
        NuiLayout.Box(main_popup, { size = "100%" }),
      }, {}),
      side = {
        top = NuiLayout.Box({
          NuiLayout.Box(side_popups.top, { size = "100%" }),
        }, {}),
        bottom = NuiLayout.Box({
          NuiLayout.Box(side_popups.bottom, { size = "100%" }),
        }, {}),
      },
    },
  }

  local layout = NuiLayout({
    position = "50%",
    relative = "editor",
    size = {
      width = "90%",
      height = "90%",
    },
  }, layout_configs.default)

  main_popup:map(
    config.keymaps.move_to_pane.right,
    "Move to side pane",
    function() vim.api.nvim_set_current_win(side_popups.top.winid) end
  )

  side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  side_popups.top:map(
    "n",
    config.keymaps.move_to_pane.bottom,
    function() vim.api.nvim_set_current_win(side_popups.bottom.winid) end
  )

  side_popups.bottom:map(
    "n",
    config.keymaps.move_to_pane.top,
    function() vim.api.nvim_set_current_win(side_popups.top.winid) end
  )

  side_popups.bottom:map(
    "n",
    config.keymaps.move_to_pane.left,
    function() vim.api.nvim_set_current_win(main_popup.winid) end
  )

  main_popup:map(config.keymaps.toggle_maximise, "Toggle maximise", function()
    if main_popup:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.top:set_maximised(false)
      side_popups.bottom:set_maximised(false)
    else
      layout:update(layout_configs.maximised.main)
      main_popup:set_maximised(true)
      side_popups.top:set_maximised(false)
      side_popups.bottom:set_maximised(false)
    end
  end)

  side_popups.top:map("n", config.keymaps.toggle_maximise, function()
    if side_popups.top:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.top:set_maximised(false)
      side_popups.bottom:set_maximised(false)
    else
      layout:update(layout_configs.maximised.side_popups.top)
      main_popup:set_maximised(false)
      side_popups.top:set_maximised(true)
      side_popups.bottom:set_maximised(false)
    end
  end)

  side_popups.bottom:map("n", config.keymaps.toggle_maximise, function()
    if side_popups.bottom:maximised() then
      layout:update(layout_configs.default)
      main_popup:set_maximised(false)
      side_popups.top:set_maximised(false)
      side_popups.bottom:set_maximised(false)
    else
      layout:update(layout_configs.maximised.side_popups.bottom)
      main_popup:set_maximised(false)
      side_popups.top:set_maximised(false)
      side_popups.bottom:set_maximised(true)
    end
  end)

  main_popup:map(config.keymaps.show_help, "Show help", function()
    if not help_popup:is_visible() then
      help_popup:set_visible(true)
      help_popup:mount()
      help_popup:focus()
    end
  end)

  help_popup:map("n", config.keymaps.hide_help, function()
    if help_popup:is_visible() then
      help_popup:set_visible(false)
      help_popup:unmount()
      -- Check if main popup is maximised
      if main_popup:maximised() then
        layout:update(layout_configs.maximised.main)
      else
        layout:update(layout_configs.default)
      end
      main_popup:focus()
    end
  end)

  return layout,
    {
      main = main_popup,
      side = side_popups,
      help = help_popup,
    }
end

return M
