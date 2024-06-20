# yazi.nvim

A neovim plugin that provides integration with [yazi](https://github.com/sxyazi/yazi)

## Dependencies

- `ya`

`ya` can be installed by downloading and compiling the source code from the [yazi]()

## Usage

With lazy.nvim:
```lua
{
    "samsze0/yazi.nvim",
    config = function()
        require("yazi").setup({})
    end,
    dependencies = {
        "samsze0/utils.nvim",
        "MunifTanjim/nui.nvim"
    }
}
```

```lua
local yazi = require("yazi")
local yazi_layout_helpers = require("yazi.layout-helpers")

local controller = yazi.Controller.new()
local layout = yazi_layout_helpers.create_single_pane_layout(controller, {})
controller:start()
```

## TODO

- Provide more user friendly API with sane OOTB defaults
- Provide option to warn user if a keymap of a popup is being overridden
- Focus back to prev win after closing popup
- Yazi event unsubscription

## License

MIT
