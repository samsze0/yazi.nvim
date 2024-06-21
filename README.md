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
        "MunifTanjim/nui.nvim",
        "samsze0/jumplist.nvim"  -- Optional
    }
}
```

```lua
local YaziBasicInstance = require("yazi.instance").BasicInstance

local yazi = YaziBasicInstance.new({})
yazi:start()
```

## TODO

- Provide option to warn user if a keymap of a popup is being overridden
- Yazi event unsubscription
- Refine helper popup
- Power instance

## License

MIT
