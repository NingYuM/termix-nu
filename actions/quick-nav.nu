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
  if ($nav-key == '' || $nav-key == 'list') { show-navs } {}
  # Find match from nav keys only
  let matchs = ($allNavs | pivot | rename key url | select key | find $nav-key)
  # If no match item was found then show all the nav items
  do -i {
    if ($matchs == $nothing) { show-navs } {}
  }

  # Found match item
  let navKey = ($matchs | nth 0).key
  let url = ($allNavs | get ($navKey | into column_path))
  if ($url | str starts-with 'http') {
    $'Going to open matched url: (ansi g)($url)(ansi reset) in default browser...(char nl)'
    # Use powershell command to open url in default browser for Windows
    if ($_OS =~ 'windows') { ^powershell -c $'Start-Process ($url)' } { ^open $url }
  } {
    $'(ansi r)Invalid nav url, bye...(char nl)(ansi reset)'
  }
}

def 'show-navs' [] {
  $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
  $allNavs | pivot | rename key url
  exit --now
}

# Merge all nav items from termix.toml and .termixrc
def 'merge-navs' [] {
  let quickNavs = (get-conf quickNavs)
  enter $nu.env.JUST_INVOKE_DIR
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { (git branch --show-current) } { 'i' })

  # let specialNavs = (if $confExists { (open .termixrc | from toml | to json | query json 'quickNavs') } { ([[]; []]) })
  # FIXME: fatal: invalid object name 'origin/i'.
  let specialNavs = (git show $'origin/($confBr):.termixrc' | from toml | to json | query json 'quickNavs')
  let allNavs = (if (($specialNavs | compact | length) == 0) { $quickNavs } {
    let navs = ($quickNavs | pivot key url)
    let special = ($specialNavs | pivot key url)
    # Concat tables, and special will override navs if they have the same key
    echo (echo $navs $special | pivot -r)
  })
  echo $allNavs
}
