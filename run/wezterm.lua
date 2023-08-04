-- Description:
--  Wezterm config file
--  Created at 2023-08-03 12:51:00
-- Usage:
--  Create soft link on Windows by pwsh:
--  gsudo New-Item -ItemType SymbolicLink -Path "~\.wezterm.lua" -Target "run\wezterm.lua"
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
  -- Candidates: Catppuccin Mocha, Argonaut, Dracula (Official), Bamboo, Omni (Gogh)
  color_scheme = is_mac and 'Dracula (Official)' or "Catppuccin Mocha",

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
}
