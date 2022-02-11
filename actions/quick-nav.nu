# Author: hustcer
# Created: 2021/11/12 15:06:56
# Description: Quickly open the nav url in default browser, for mac and windows
# Usage:
#   just go

let allNavs = (merge-navs)

def 'go' [
  nav-key?: string  # The nav key to go from `quickNavs` config in termix.toml
] {

  # If the key of `just go` is blank or list, then show all the nav items
  if ($nav-key == '' || $nav-key == 'list') { show-navs }
  # Find match from nav keys only
  let matchs = ($allNavs | transpose | rename key url | select key | find $nav-key)
  # If no match item was found then show all the nav items
  if ($matchs | length) == 0 { show-navs }

  # Found match item
  let navKey = ($matchs | get key).0
  let url = ($allNavs | get $navKey).0
  if ($url | str starts-with 'http') {
    $'Going to open matched url: (ansi g)($url)(ansi reset) in default browser...(char nl)'
    # Use powershell command to open url in default browser for Windows
    if ($_OS =~ 'windows') { ^powershell -c $'Start-Process ($url)' } else { ^open $url }
  } else {
    $'(ansi r)Invalid nav url, bye...(char nl)(ansi reset)'
  }
}

def 'show-navs' [] {
  $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
  $allNavs | transpose | rename key url
  exit --now
}

# Merge all nav items from termix.toml and .termixrc
def 'merge-navs' [] {
  let quickNavs = (get-conf quickNavs)
  enter $env.JUST_INVOKE_DIR
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { (git branch --show-current | str trim) } else { 'i' })

  # let specialNavs = (if $confExists { (open .termixrc | from toml | to json | query json 'quickNavs') } { ([[]; []]) })
  # FIXME: fatal: invalid object name 'origin/i'.
  let specialNavs = (git show $'origin/($confBr):.termixrc' | from toml | to json | query json 'quickNavs')
  let allNavs = (if (($specialNavs | compact | length) == 0) { $quickNavs } else {
    let navs = ($quickNavs | transpose key url)
    let special = ($specialNavs | transpose key url)
    # Concat tables, and special will override navs if they have the same key
    echo (echo $navs $special | flatten | transpose -r)
  })
  echo $allNavs
}
