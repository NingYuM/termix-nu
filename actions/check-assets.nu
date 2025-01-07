#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/06/23 12:06:56
# Description: Query and preview TERP assets status.
# [√] Select and query with fzf
# [√] Preview the meta data of selected assets

use terp-assets.nu ['terp assets']
use ../utils/common.nu [ECODE, FZF_KEY_BINDING, FZF_THEME]

const FZF_DEFAULT_OPTS = $'--multi --height 80% --layout=reverse --highlight-line --marker ▏ --pointer ▌ --prompt "▌ " --preview-window=right:90% ($FZF_KEY_BINDING)'

export def 'check assets' [] {
  cd $env.TERMIX_DIR
  let MOUNT_POINTS = open .termixrc | from toml | get -i terp.assets | default {}
  let title = $'Select assets:'
  let PREVIEW_CMD = $"nu actions/check-assets.nu {}"
  let FZF_PREVIEW_CONF = $'--preview "($PREVIEW_CMD)"'
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($title)" ($FZF_PREVIEW_CONF) ($FZF_THEME)'
  let selected = $MOUNT_POINTS | columns | str join (char nl) | fzf | complete | get stdout | str trim
  if ($selected | is-empty) { return }
  $selected | lines | each {|it|
    terp assets detect -f ($MOUNT_POINTS | get $it); print -n (char nl)
  } | ignore
}

def main [selected: string] {
  cd $env.TERMIX_DIR
  $env.config.table.mode = 'light'
  $env.config.table.index_mode = 'never'
  $env.config.table.padding = { left: 0, right: 0 }
  let MOUNT_POINTS = open .termixrc | from toml | get -i terp.assets
  terp assets detect -f ($MOUNT_POINTS | get $selected)
}
