# Buffer Switcher
IDE like switcher for nvim opened buffers.

## Features
- Switch between open buffers like an app switcher or switcher in IDE.
- Preconfigured modes that offers different styles of cycling opened buffers.
  - `preview` - Trouble.nvim like preview of the buffer while cycling buffers
  - `popup` - Similar to a picker with minimal popup and sensible key maps.
  - `timeout` - Most resembles a switcher that is based on timeout.
- Many configuration options to customize behaviour.

## Requirements
- Tested on mac and nvim v0.10.4
- Dependency on nui.nvim for popup

## Installation
### Lazy.nvim
```lua
{
  "benzhou1/buf_switcher.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {},
}
```

## Setup
```lua
  ---@class bufSwitcher.Config.Timeout
  ---@field enabled boolean? Enable timeout to close popup
  ---@field value integer? Milliseconds to keep popup open before selecting the current buffer to open

  ---@class bufSwitcher.Config.Preview
  ---@field enabled boolean? Enable preview buffer

  ---@class bufSwitcher.Config.Autocmds
  ---@field enabled boolean? Enable autocmds for cursor movements

  ---@class bufSwitcher.Config.Highlights
  ---@field current_buf string? Highlight group for currently selected line in popup
  ---@field filename string? Highlight group for filename
  ---@field dirname string? Highlight group for dirname
  ---@field lnum string? Highlight group for line number

  ---@class bufSwitcher.Config.Keymaps
  ---@field enabled boolean? Enable auto mapping of keys
  ---@field prev string? Keybind to use for switching to previous buffer. Set to false to disable.
  ---@field next string? Keybind to use for switching to next buffer. Set to false to disable.

  ---@class bufSwitcher.Config.Hooks.Options
  ---@field preview_bufnr integer? Preview buffer number, if preview is enabled
  ---@field prev_win_id integer Previous window id
  ---@field prev_buf table Previous buffer info
  ---@field target_buf table Target buffer info
  ---@field popup NuiPopup? Popup object

  ---@class bufSwitcher.Config.Hooks
  ---@field before_show_preview fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing preview buffer
  ---@field after_show_preview fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing preview buffer
  ---@field before_show_target fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing target buffer
  ---@field after_show_target fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing target buffer
  ---@field before_show_popup fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run before showing popup menu
  ---@field after_show_popup fun(opts: bufSwitcher.Config.Hooks.Options)? Hook to run after showing popup menu

  ---@class bufSwitcher.Config
  ---@field timeout bufSwitcher.Config.Timeout? Describes the timeout configuration
  ---@field preview bufSwitcher.Config.Preview? Describes the preview configuration
  ---@field autocmds bufSwitcher.Config.Autocmds? Describes the autocmds configuration
  ---@field highlights bufSwitcher.Config.Highlights? Describes the highlights configuration
  ---@field keymaps bufSwitcher.Config.Keymaps? Configure keymaps
  ---@field hooks bufSwitcher.Config.Hooks? Configure hooks
  ---@field popup table? Options for nui popup buffer
  ---@field mode "preview" | "popup" | "timeout"? Pre configured modes, defaults to preview
  ---| "preview" - Preview of the target buffer is shown as buffers are cycled to create a seamless switching experience.
  ---   Any cursor movements or text changes will open the target buffer.
  ---   After elapsed timeout the target buffer will be opened.
  ---| "popup" - Preview is disabled and popup buffer list will be focused allowing you to select the buffer to open with <CR>.
  ---   Buffer list can be navigated with movement keys. You must manually choose which buffer to open with no timeout.
  ---| "timeout" - Same as popup, but with timeout only and no key mas. This mode resembles a switcher the most, but relies on timeout.
  ---| nil - Set to nil to ignore preconfigured modes and use custom configuration.
  ---@type bufSwitcher.Config
  opts = {
    mode = "preview",
    timeout = {
      enabled = true,
      value = 1000,
    },
    preview = {
      enabled = true,
    },
    autocmds = {
      enabled = true,
    },
    highlights = {
      current_buf = "Visual",
      filename = "Normal",
      dirname = "Comment",
      lnum = "DiagnosticInfo",
    },
    hooks = {
      -- See buf_switcher/init.lua
      before_show_preview = M.before_show_preview,
      after_show_preview = M.after_show_preview,
      before_show_target = M.before_show_target,
      after_show_target = M.after_show_target,
      after_show_popup = M.after_show_popup,
      before_show_popup = M.before_show_popup,
    },
    keymaps = {
      enabled = true,
      prev = "<C-S-Tab>",
      next = "<C-Tab>",
    },
    popup = {
      enter = false,
      focusable = false,
      map_keys = false,
      border = {
        style = "rounded",
        text = {
          top = "Buf Switcher",
          top_align = "left",
        },
      },
      relative = "editor",
      position = {
        row = "50%",
        col = "70%",
      },
      size = {
        width = 50,
        height = 10,
      },
    },
  }
}
```

## Usage
By default cycling forwards and backwards is mapped to `<C-Tab>` and `<C-S-Tab`.

### Commands
Similarly the user commands `BufSwticherNext` and `BufSwitcherPrev` are available for custom mappings. Lua functions `require("buf_switcher").next_buf` and `require("buf_switcher").prev_buf` are available as well. To use custom keymap set `keymaps.enabled = false`.

## Highlights
These highlights are configurable through setup opts. See setup section for more details.
```lua
{
  current_buf = "Visual",
  filename = "Normal",
  dirname = "Comment",
  lnum = "DiagnosticInfo",
}
```
## Acknowledgements
- [Trouble.nvim](https://github.com/folke/trouble.nvim?tab=readme-ov-file) for preview buffers.
- [Nui.nvim](https://github.com/MunifTanjim/nui.nvim) for popup.

