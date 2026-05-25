# tr181.nvim

TR-181 plugin

Based on Broadband Forum TR-181 Device:2.20

i made this cuz Broadban forum web is soooo heavy

## Prerequisites

- Neovim >= 0.8
- Python 3
- [fzf](https://github.com/junegunn/fzf) (optional, for fzf search)

## Installation

### 1. Plugin (lazy.nvim)

```lua
{
    'tae9898/tr181.nvim',
    config = function()
        require('tr181').setup()
    end,
}
```

### 2. CLI + XML Data

```bash
git clone https://github.com/tae9898/tr181.nvim.git
cd tr181.nvim
./install.sh
```

What `install.sh` does:
- Installs `tr181` Python CLI → `~/.local/bin/tr181`
- Downloads TR-181 Device:2.20 XML → `~/.tr181/tr-181.xml`

## Configuration

```lua
require('tr181').setup({
    tr181_cmd      = "tr181",         -- CLI path (override with TR181_CMD env var)
    panel_width    = 60,              -- Side panel width
    panel_side     = "right",         -- "right" | "left"
    search_limit   = 50,              -- Max search results
    keymap_prefix  = "<leader>t",     -- Keymap prefix
    enable_keymaps = true,            -- Enable default keymaps
})
```

## Keymaps

| Key | Action |
|---|---|
| `<leader>ts` | Search by keyword |
| `<leader>tS` | Search cursor word |
| `<leader>tf` | fzf full search (with preview) |
| `<leader>tt` | fzf tree explorer |
| `<leader>to` | Show detail |
| `<leader>tp` | Show parameters |
| `<leader>tq` | Close panel |
| `<leader>ti` | Statistics |

### Inside Side Panel

| Key | Action |
|---|---|
| `s` / `/` | New search |
| `Enter` | Show detail |
| `p` | Show params |
| `b` | Go back |
| `q` | Close panel |

## Standalone CLI

```bash
# Search
tr181 search WiFi

# Show detail
tr181 show Device.WiFi.

# List objects
tr181 list Device.WiFi.

# List parameters
tr181 params Device.WiFi.Radio.{i}.

# Tree view
tr181 tree Device.WiFi. --depth 3

# Interactive fzf
tr181 fzf

# Statistics
tr181 stats
```

## Data

- Spec: TR-181 Device:2.20 (CWMP)
- Source: [Broadband Forum CWMP Data Models](https://cwmp-data-models.broadband-forum.org/)
- XML data is licensed under Broadband Forum terms.

## License

- Plugin code (Lua, Python): MIT
- TR-181 XML data: [Broadband Forum](https://cwmp-data-models.broadband-forum.org/) license
