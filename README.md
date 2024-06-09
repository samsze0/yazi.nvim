# yazi.nvim

A neovim plugin that provides integration with [yazi](https://github.com/sxyazi/yazi)

## Usage

```lua
{
    "samsze0/yazi.nvim",
    config = function()
        require("yazi").setup({})
    end
}
```

```lua
local YaziController = require("yazi").Controller

YaziController.new():start()
```

## TODO

- Provide option to warn user if a keymap of a popup is being overridden

## License

MIT
