-- Description:
--  Wezterm config file
--  Created at 2023-08-03 12:51:00
-- Usage:
--  Create soft link on Windows by pwsh:
--  gsudo New-Item -ItemType SymbolicLink -Path "~\.wezterm.lua" -Target "run\wezterm.lua"
-- Install:
--  Windows: scoop install wezterm
--  MacOS: brew install --cask wezterm, brew install --cask wezterm-nightly, brew upgrade --cask wezterm-nightly --no-quarantine --greedy-latest
-- REF:
--  1. https://wezfurlong.org/wezterm/config/files.html
--  2. https://wezfurlong.org/wezterm/config/default-keys.html
--  3. https://wezfurlong.org/wezterm/colorschemes/index.html

local wezterm = require 'wezterm';
local act = wezterm.action;

local is_mac = string.find(wezterm.target_triple, 'apple-darwin', 0, true) and true or false

return {
  initial_rows = 25,
  initial_cols = 100,
  font_size = is_mac and 20 or 15,
  window_background_opacity = 1,
  window_decorations = is_mac and "RESIZE" or "INTEGRATED_BUTTONS|RESIZE",

  -- Command Palette settings
  command_palette_fg_color = '#FFF',
  -- 655,6F3B80,7F7180
  command_palette_bg_color = "#7F7180",
  command_palette_font_size = is_mac and 18 or 13,
  -- Selected: Catppuccin Mocha, Argonaut, Dracula (Official), Omni (Gogh)
  -- Calamity, Chalkboard, Desert, Earthsong, Flatland, Foxnightly (Gogh)
  -- GitHub Dark, Glacier, Gogh (Gogh), Google Dark (Gogh), GruvboxDark
  -- Grape
  color_scheme = is_mac and 'Desert' or "Desert",
  colors = {
    -- 被选中的内容的背景色
    selection_bg = '#7F7180'
  },

  -- Font settings
  font = wezterm.font_with_fallback {
    'Fira Code',
    'JetBrains Mono',
    'Source Code Pro',
    'Cascadia Code',
  },

  max_fps = 60,
  animation_fps = 60,
  front_end = 'WebGpu',
  webgpu_power_preference = 'HighPerformance',

  -- Scrollbar
  enable_scroll_bar = false,

  -- How many lines of scrollback you want to retain per tab
  scrollback_lines = 5000,

  -- Tab bar
  enable_tab_bar = not is_mac,
  tab_max_width = 25,
  use_fancy_tab_bar = true,
  tab_bar_at_bottom = false,
  show_tab_index_in_tab_bar = false,
  hide_tab_bar_if_only_one_tab = false,
  switch_to_last_active_tab_when_closing_tab = true,

  -- Keys REF: https://wezfurlong.org/wezterm/config/keys.html
  keys = {
    { key = 'Enter', mods = 'CMD', action = act.ToggleFullScreen },
    { key = 'p', mods = 'CMD', action = act.ActivateCommandPalette },
    -- Tabs: navigation
    { key = 'LeftArrow', mods = 'CMD', action = act.ActivateTabRelative(-1) },
    { key = 'RightArrow', mods = 'CMD', action = act.ActivateTabRelative(1) },
    -- Split panes
    {
      key = 'V',
      mods = 'CTRL|SHIFT|CMD',
      action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },
    {
      key = 'H',
      mods = 'CTRL|SHIFT|CMD',
      action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    { key = 'S', mods = 'CTRL|SHIFT', action = wezterm.action.QuickSelect },
    -- Edit tab title
    {
      key = 'E',
      mods = 'CTRL|SHIFT',
      action = act.PromptInputLine {
        description = 'Enter new name for tab',
        action = wezterm.action_callback(function(window, pane, line)
          -- line will be `nil` if they hit escape without entering anything
          -- An empty string if they just hit enter
          -- Or the actual line of text they wrote
          if line then
            window:active_tab():set_title(line)
          end
        end),
      },
    },
  },

  mouse_bindings = {
    -- Change the default click behavior so that it only selects
    -- text and doesn't open hyperlinks
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'NONE',
      action = act.CompleteSelection 'ClipboardAndPrimarySelection',
    },

    -- and make CTRL-Click open hyperlinks
    {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
    },
    -- NOTE that binding only the 'Up' event can give unexpected behaviors.
    -- Read more below on the gotcha of binding an 'Up' event only.
  },

  unix_domains = {
    { name = 'unix' }
  },
}
