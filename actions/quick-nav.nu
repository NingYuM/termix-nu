#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/12 15:06:56
# Description: Quickly open the nav url in default browser, for mac and windows
# Usage:
#   just go

use ../utils/common.nu [get-conf windows?]

export def 'go' [
  nav_key?: string  # The nav key to go from `quickNavs` config in termix.toml
] {

  let allNavs = merge-navs
  # If the key of `just go` is blank or list, then show all the nav items
  if ($nav_key == '' or $nav_key == 'list') { show-navs }
  # Find match from nav keys only
  let matches = ($allNavs | transpose | rename key url | select key | find -i -r $nav_key)
  # If no match item was found then show all the nav items
  if ($matches | length) == 0 { show-navs }

  # Found match item
  let navKey = ($matches | get key).0
  let url = $allNavs | get $navKey
  if ($url | str starts-with 'http') {
    print $'Going to open matched url: (ansi g)($url)(ansi reset) in default browser...(char nl)'
    # Use powershell command to open url in default browser for Windows
    if (windows?) { ^powershell -c $'Start-Process ($url)' } else { ^open $url }
  } else {
    print $'(ansi r)Invalid nav url, bye...(char nl)(ansi reset)'
  }
}

export def 'show-navs' [] {
  print $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
  print (merge-navs | transpose | rename key url)
  exit 0
}

# Merge all nav items from termix.toml and .termixrc
export def 'merge-navs' [] {
  let quickNavs = get-conf quickNavs
  enter $env.JUST_INVOKE_DIR
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = get-conf useConfFromBranch
  let confBr = if $useConfBr == '_current_' { (git branch --show-current | str trim) } else { 'i' }

  let termixrc = (do -i { git show $'origin/($confBr):.termixrc' })
  let specialNavs = if ($termixrc | is-empty) { {} } else { ( $termixrc | from toml | to json | query json 'quickNavs') }
  let rcNavs = get-rc-navs
  let rcNavs = if ($rcNavs | is-empty) { {} } else { $rcNavs }
  let allNavs = ($quickNavs | merge $specialNavs | merge $rcNavs)
  $allNavs
}

# Get nav items from .termixrc
def get-rc-navs [] {
  let LOCAL_CONFIG = if ('.termixrc' | path exists) { '.termixrc' } else { $'($env.TERMIX_DIR)/.termixrc' }
  let hasRc = $LOCAL_CONFIG | path exists
  let rcNavs = (
    if $hasRc {
      (open $LOCAL_CONFIG | from toml | to json | query json 'quickNavs')
    }
  )
  $rcNavs
}
