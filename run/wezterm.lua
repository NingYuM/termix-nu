-- Description:
--  Wezterm config file
--  Created at 2023-08-03 12:51:00
-- REF:
--  1. https://wezfurlong.org/wezterm/config/files.html
--  2. https://wezfurlong.org/wezterm/config/default-keys.html
--  3. https://wezfurlong.org/wezterm/colorschemes/index.html

local wezterm = require 'wezterm';
local act = wezterm.action;

return {
  font_size = 20,
  initial_rows = 25,
  initial_cols = 100,
  window_decorations = "RESIZE",
  color_scheme = "Dracula (Official)", -- or Catppuccin Mocha, Macchiato, Frappe, Latte, Dracula (Official)

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
  enable_tab_bar = false,
  tab_max_width = 25,
  tab_bar_at_bottom = true,
  use_fancy_tab_bar = false,
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
