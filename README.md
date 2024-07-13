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
        "samsze0/tui.nvim",
        "samsze0/utils.nvim",
        "MunifTanjim/nui.nvim",
        "samsze0/jumplist.nvim"  -- Optional
    }
}
```

```lua
local YaziPowerInstance = require("yazi.instance").PowerInstance

local yazi = YaziPowerInstance.new({})
yazi:start()
```

## TODO

- Dynamically switch between nvim preview and yazi preview (and ditch usage of eza)

## License

MIT
