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
        require("yazi").setup({
          keymaps = {
            open = "<f2>",
            hide = "<f2>",
            open_in_new_window = "<C-w>",
            open_in_new_tab = "<C-t>",
            reveal_current_file = "<f3>",
          },
        })
    end,
    dependencies = {
        "samsze0/tui.nvim",
        "samsze0/utils.nvim",
        "MunifTanjim/nui.nvim",
        "samsze0/jumplist.nvim"  -- Optional
    }
}
```

## TODO

- Dynamically switch between nvim preview and yazi preview (and ditch usage of eza)

## License

MIT
