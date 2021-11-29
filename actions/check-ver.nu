# Author: hustcer
# Created: 2021/10/14 10:06:56
# Description: Check the current nushell version
# Usage:
#   nu-ver

# Check min nushell version and show upgrading tips to the user
def 'nu-ver' [] {

  let currentVer = ((version).version)
  let minVer = (get-conf minNuVer '0.40.0')
  upgrade-tip nushell $minVer $currentVer
}

# Check min just version and show upgrading tips to the user
def 'just-ver' [] {

  let currentVer = (just --version | str find-replace 'just' '' | str trim | first)
  let minVer = (get-conf minJustVer '0.10.4')
  upgrade-tip just $minVer $currentVer
}

# Compare min version with current version and show upgrading tips if required
def 'upgrade-tip' [
  cmd: string,
  min: string,
  current: string,
] {
  let m = ($min | split row '.' | each { $it | into int })
  let c = ($current | split row '.' | each { $it | into int })
  if (($c.0 < $m.0) || ($c.1 < $m.1) || ($c.2 < $m.2)) {
    $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    $'  Min required ($cmd) ver: (ansi r)($min)(ansi reset), current ($cmd) ver: ($current)(char nl)'
    $'  ------------> Your ($cmd) is (ansi r)OUTDATED(ansi reset) <------------ (char nl)'
    $'  Please run (ansi g)`brew upgrade ($cmd)`(ansi reset) to upgrade to the latest.(char nl)'
    $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    exit --now
  } {}
}
