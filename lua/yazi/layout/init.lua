local NuiLayout = require("nui.layout")
local MainPopup = require("yazi.layout.popup").MainPopup
local SidePopup = require("yazi.layout.popup").SidePopup
local config = require("yazi").config
local opts_utils = require("utils.opts")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- TODO: generics on Popup class

---@alias YaziLayoutMainPopupOptions { class?: YaziMainPopup }
---@alias YaziLayoutSidePopupOptions { class?: YaziSidePopup, extra_options?: nui_popup_options }

---@alias YaziLayoutSinglePaneOptions { main_popup?: YaziLayoutMainPopupOptions }
---@param opts? YaziLayoutSinglePaneOptions
---@return NuiLayout layout, { main: YaziMainPopup } popups
M.single_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
  }, opts)
  ---@cast opts YaziLayoutSinglePaneOptions

  local main_popup = opts.main_popup.class.new()

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "100%" }),
    }, {})
  )

  return layout, {
    main = main_popup,
  }
end

---@alias YaziLayoutDualPaneOptions { main_popup?: YaziLayoutMainPopupOptions, side_popup?: YaziLayoutSidePopupOptions }
---@param opts? YaziLayoutDualPaneOptions
---@return NuiLayout, { main: YaziMainPopup, side: YaziSidePopup }
M.dual_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts YaziLayoutDualPaneOptions

  local main_popup = opts.main_popup.class.new()

  local side_popup = opts.side_popup.class.new(opts.side_popup.extra_options)

  local popups = { main = main_popup, side = side_popup }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box(side_popup, { size = "50%" }),
    }, { dir = "row" })
  )

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

  return layout, popups
end

---@alias YaziLayoutTriplePaneOptions { main_popup?: YaziLayoutMainPopupOptions, left_side_popup?: YaziLayoutSidePopupOptions, right_side_popup?: YaziLayoutSidePopupOptions }
---@param opts? YaziLayoutTriplePaneOptions
---@return NuiLayout layout, { main: YaziMainPopup, side: { left: YaziSidePopup, right: YaziSidePopup } } popups
M.triple_pane = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    left_side_popup = {
      class = SidePopup,
    },
    right_side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts YaziLayoutTriplePaneOptions

  local main_popup = MainPopup.new()

  local side_popups = {
    left = opts.left_side_popup.class.new(opts.left_side_popup.extra_options),
    right = opts.right_side_popup.class.new(
      opts.right_side_popup.extra_options
    ),
  }

  local popups = { main = main_popup, side = side_popups }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "95%",
        height = "95%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "30%" }),
      NuiLayout.Box(side_popups.left, { size = "35%" }),
      NuiLayout.Box(side_popups.right, { size = "35%" }),
    }, { dir = "row" })
  )

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

  return layout, popups
end

---@alias YaziLayoutTriplePane2ColumnOptions { main_popup?: YaziLayoutMainPopupOptions, top_side_popup?: YaziLayoutSidePopupOptions, bottom_side_popup?: YaziLayoutSidePopupOptions }
---@param opts? YaziLayoutTriplePane2ColumnOptions
---@return NuiLayout, { main: YaziMainPopup, side: { top: YaziSidePopup, bottom: YaziSidePopup } }
M.triple_pane_2_column = function(opts)
  opts = opts_utils.deep_extend({
    main_popup = {
      class = MainPopup,
    },
    top_side_popup = {
      class = SidePopup,
    },
    bottom_side_popup = {
      class = SidePopup,
    },
  }, opts)
  ---@cast opts YaziLayoutTriplePane2ColumnOptions

  local main_popup = MainPopup.new()

  local side_popups = {
    top = opts.top_side_popup.class.new(opts.top_side_popup.extra_options),
    bottom = opts.bottom_side_popup.class.new(
      opts.bottom_side_popup.extra_options
    ),
  }

  local layout = NuiLayout(
    {
      position = "50%",
      relative = "editor",
      size = {
        width = "90%",
        height = "90%",
      },
    },
    NuiLayout.Box({
      NuiLayout.Box(main_popup, { size = "50%" }),
      NuiLayout.Box({
        NuiLayout.Box(side_popups.top, { size = "20%" }),
        NuiLayout.Box(side_popups.bottom, { grow = 1 }),
      }, { size = "50%", dir = "col" }),
    }, { dir = "row" })
  )

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

  return layout, {
    main = main_popup,
    side = side_popups,
  }
end

return M
