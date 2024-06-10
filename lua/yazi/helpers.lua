local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local config = require("yazi.config")
local jumplist = require("jumplist")
local NuiEvent = require("nui.utils.autocmd").event
local layouts = require("yazi.layout")

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- Configure remote navigation between main and target popup.
--
---@param main_popup YaziMainPopup
---@param target_popup YaziSidePopup
M.configure_remote_nav = function(main_popup, target_popup)
  main_popup:map_remote(
    target_popup,
    "Scroll preview up",
    config.keymaps.remote_scroll_preview_pane.up
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview left",
    config.keymaps.remote_scroll_preview_pane.left
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview down",
    config.keymaps.remote_scroll_preview_pane.down
  )
  main_popup:map_remote(
    target_popup,
    "Scroll preview right",
    config.keymaps.remote_scroll_preview_pane.right
  )
end

-- Configure file open keymaps
--
---@param main_popup YaziMainPopup
---@param controller YaziController
---@param opts { filepath_accessor: (fun(focus: any): string) }
M.configure_file_open_keymaps = function(main_popup, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
  }, opts)

  main_popup:map("<C-w>", "Open in new window", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[vsplit %s]]):format(filepath))
  end)

  main_popup:map("<C-t>", "Open in new tab", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[tabnew %s]]):format(filepath))
  end)

  main_popup:map("<CR>", "Open", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    jumplist.save()
    vim.cmd(([[e %s]]):format(filepath))
  end)
end

-- Configure file preview.
--
---@param main_popup YaziMainPopup
---@param preview_popup YaziSidePopup
---@param controller YaziController
---@param opts { setup_file_open_keymaps?: boolean, filepath_accessor: (fun(focus: any): string) }
M.configure_filepreview = function(main_popup, preview_popup, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
  }, opts)

  controller:subscribe("focus", function(payload)
    local focus = controller.focus

    preview_popup:set_lines({})

    if not focus then return end

    preview_popup:show_file_content(opts.filepath_accessor(focus))
  end)

  -- TODO: source keybinds from config

  main_popup:map("<C-y>", "Copy filepath", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)

  if opts.setup_file_open_keymaps then
    M.configure_file_open_keymaps(main_popup, controller, opts)
  end
end

---@param main_popup YaziMainPopup
---@param help_popup YaziHelpPopup
M.configure_help_popup = function(main_popup, help_popup)
  help_popup:set_keymaps(main_popup:keymaps())
end

---@param layout NuiLayout
---@param main_popup YaziMainPopup
---@param controller YaziController
M.configure_controller_ui_hooks = function(layout, main_popup, controller)
  controller:set_ui_hooks({
    show = function() layout:show() end,
    hide = function() layout:hide() end,
    focus = function() main_popup:focus() end,
    destroy = function() layout:unmount() end,
  })
end

-- Layout & popup configurations for previewing code
--
---@alias YaziLayoutDualPaneCodePreviewOptions { filepath_accessor: (fun(focus: any): string), main_popup?: YaziMainPopup, side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup }
---@param controller YaziController
---@param opts YaziLayoutDualPaneCodePreviewOptions
---@return NuiLayout, { main: YaziMainPopup, side: YaziSidePopup }
M.dual_pane_code_preview = function(controller, opts)
  opts = opts_utils.deep_extend({
    side_popup = {
      extra_options = {
        win_options = {
          number = true,
          cursorline = true,
        },
      },
    },
  }, opts)
  ---@cast opts YaziLayoutDualPaneCodePreviewOptions

  local layout, popups = layouts.dual_pane({
    main_popup = opts.main_popup,
    side_popup = opts.side_popup,
    help_popup = opts.help_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side)
  M.configure_help_popup(popups.main, popups.help)

  M.configure_filepreview(popups.main, popups.side, controller, {
    setup_file_open_keymaps = true,
    filepath_accessor = opts.filepath_accessor,
  })

  return layout, popups
end

-- Layout & popup configurations for code diff
--
---@alias YaziLayoutTriplePaneCodeDiffOptions { filepath_accessor: (fun(focus: any): string), main_popup?: YaziMainPopup, left_preview_popup?: YaziSidePopup, right_preview_popup?: YaziSidePopup }
---@param controller YaziController
---@param opts? YaziLayoutTriplePaneCodeDiffOptions
---@return NuiLayout, { main: YaziMainPopup, side: { left: YaziSidePopup, right: YaziSidePopup } }
M.triple_pane_code_diff = function(controller, opts)
  opts = opts_utils.deep_extend({
    left_preview_popup = {
      extra_options = {
        win_options = {
          number = true,
        },
      },
    },
    right_preview_popup = {
      extra_options = {
        win_options = {
          number = true,
        },
      },
    },
  }, opts)
  ---@cast opts YaziLayoutTriplePaneCodeDiffOptions

  local layout, popups = layouts.triple_pane({
    main_popup = opts.main_popup,
    left_side_popup = opts.left_preview_popup,
    right_side_popup = opts.right_preview_popup,
  })

  M.configure_controller_ui_hooks(layout, popups.main, controller)
  M.configure_remote_nav(popups.main, popups.side.left)
  M.configure_help_popup(popups.main, popups.help)

  return layout, popups
end

return M
