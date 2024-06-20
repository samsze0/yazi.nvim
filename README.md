# yazi.nvim

A neovim plugin that provides integration with [yazi](https://github.com/sxyazi/yazi)

## Dependencies

- `ya`

`ya` can be installed by downloading and compiling the source code from the [yazi]()

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
- Support customizing helper layouts and popups
- Focus back to prev win after closing popup
- Yazi event unsubscription

## License

MIT
