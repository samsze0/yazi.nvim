local opts_utils = require("utils.opts")
local tbl_utils = require("utils.table")
local terminal_utils = require("utils.terminal")
local config = require("yazi.config").config
local jumplist = require("jumplist")
local NuiEvent = require("nui.utils.autocmd").event
local DualPaneLayout = require("yazi.layout").DualPaneLayout
local TriplePaneLayout = require("yazi.layout").TriplePaneLayout
local MainPopup = require("yazi.layout.popup").MainPopup
local SidePopup = require("yazi.layout.popup").SidePopup

local _info = config.notifier.info
local _warn = config.notifier.warn
local _error = config.notifier.error

local M = {}

-- Configure remote navigation between main and target popup.
--
---@param layout YaziLayout
---@param target_popup YaziSidePopup
M.configure_remote_nav = function(layout, target_popup)
  layout.main_popup:map_remote(
    target_popup,
    "Scroll preview up",
    config.keymaps.remote_scroll_preview_pane.up
  )
  layout.main_popup:map_remote(
    target_popup,
    "Scroll preview left",
    config.keymaps.remote_scroll_preview_pane.left
  )
  layout.main_popup:map_remote(
    target_popup,
    "Scroll preview down",
    config.keymaps.remote_scroll_preview_pane.down
  )
  layout.main_popup:map_remote(
    target_popup,
    "Scroll preview right",
    config.keymaps.remote_scroll_preview_pane.right
  )
end

-- Configure file open keymaps
--
---@param layout YaziLayout
---@param controller YaziController
---@param opts { filepath_accessor: (fun(focus: any): string) }
M.configure_file_open_keymaps = function(layout, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
  }, opts)

  layout.main_popup:map(config.keymaps.file_open.new_window, "Open in new window", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[vsplit %s]]):format(filepath))
  end)

  layout.main_popup:map(config.keymaps.file_open.new_tab, "Open in new tab", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    vim.cmd(([[tabnew %s]]):format(filepath))
  end)

  layout.main_popup:map(config.keymaps.file_open.current_window, "Open", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    controller:hide()
    jumplist.save()
    vim.cmd(([[e %s]]):format(filepath))
  end)
end

-- Configure file preview.
--
---@param layout YaziLayout
---@param preview_popup YaziSidePopup
---@param controller YaziController
---@param opts { setup_file_open_keymaps?: boolean, filepath_accessor: (fun(focus: any): string) }
M.configure_filepreview = function(layout, preview_popup, controller, opts)
  opts = opts_utils.extend({
    filepath_accessor = function(focus) return focus.filepath end,
  }, opts)

  controller:subscribe("focus", function(payload)
    local focus = controller.focus

    preview_popup:set_lines({})

    if not focus then return end

    preview_popup:show_file_content(opts.filepath_accessor(focus))
  end)

  layout.main_popup:map(config.keymaps.copy_filepath_to_clipboard, "Copy filepath", function()
    if not controller.focus then return end

    local filepath = opts.filepath_accessor(controller.focus)
    vim.fn.setreg("+", filepath)
    _info(([[Copied %s to clipboard]]):format(filepath))
  end)

  if opts.setup_file_open_keymaps then
    M.configure_file_open_keymaps(layout, controller, opts)
  end
end

---@param layout YaziLayout
M.configure_help_popup = function(layout)
  layout.help_popup:set_keymaps(layout.main_popup:keymaps())
end

---@param layout YaziLayout
---@param controller YaziController
M.configure_controller_ui_hooks = function(layout, controller)
  controller:set_ui_hooks({
    show = function() layout:show() end,
    hide = function() layout:hide() end,
    focus = function() layout.main_popup:focus() end,
    destroy = function() layout:unmount() end,
  })
end

-- Create yazi layout for previewing code
--
---@alias YaziCreateDualPaneCodePreviewLayoutOptions { filepath_accessor: (fun(focus: any): string), main_popup?: YaziMainPopup, side_popup?: YaziSidePopup, help_popup?: YaziHelpPopup }
---@param controller YaziController
---@param opts YaziCreateDualPaneCodePreviewLayoutOptions
---@return YaziDualPaneLayout
M.create_dual_pane_code_preview_layout = function(controller, opts)
  opts = opts_utils.deep_extend({
    side_popup = SidePopup.new({
      win_options = {
        number = true,
        cursorline = true,
      },
    })
  }, opts)
  ---@cast opts YaziCreateDualPaneCodePreviewLayoutOptions

  local layout = DualPaneLayout.new({
    main_popup = opts.main_popup,
    side_popup = opts.side_popup,
  })
  layout:setup_keymaps()

  M.configure_controller_ui_hooks(layout, controller)
  M.configure_remote_nav(layout, layout.side_popup)
  M.configure_help_popup(layout)

  M.configure_filepreview(layout, layout.side_popup, controller, {
    setup_file_open_keymaps = true,
    filepath_accessor = opts.filepath_accessor,
  })

  return layout
end

-- Create yazi layout for code diff
--
---@alias YaziCreateTriplePaneCodeDiffLayoutOptions { filepath_accessor: (fun(focus: any): string), main_popup?: YaziMainPopup, left_preview_popup?: YaziSidePopup, right_preview_popup?: YaziSidePopup }
---@param controller YaziController
---@param opts? YaziCreateTriplePaneCodeDiffLayoutOptions
---@return YaziTriplePaneLayout
M.triple_pane_code_diff = function(controller, opts)
  opts = opts_utils.deep_extend({
    left_preview_popup = SidePopup.new({
      win_options = {
        number = true,
      },
    }),
    right_preview_popup = SidePopup.new({
      win_options = {
        number = true,
      },
    }),
  }, opts)
  ---@cast opts YaziCreateTriplePaneCodeDiffLayoutOptions

  local layout = TriplePaneLayout.new({
    main_popup = opts.main_popup,
    side_popups = {
      left = opts.left_preview_popup,
      right = opts.right_preview_popup,
    }
  })
  layout:setup_keymaps()

  M.configure_controller_ui_hooks(layout, controller)
  M.configure_remote_nav(layout, layout.side_popups.left)
  M.configure_help_popup(layout)

  return layout
end

return M
