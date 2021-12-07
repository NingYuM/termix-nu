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
  let minVer = (get-conf minJustVer '0.10.5')
  upgrade-tip just $minVer $currentVer
}

# Check latest termix-nu version and show upgrading tips if there is a new release
def 'termix-ver' [] {
  let tmpPath = (get-tmp-path)
  let currentVer = (get-conf version)
  let confName = ([$tmpPath '.termix-conf'] | path join)
  let checkDate = (date now | date format $_DATE_FMT)
  if ($confName | path exists) {
    let conf = (open $confName -r)
    if ($conf | query json 'checkDate') == $checkDate {
      let latestVer = ($conf | query json 'latestVer')
      upgrade-tip termix-nu $latestVer $currentVer
    } {
      upgrade-tip termix-nu (query-ver $confName) $currentVer
    }
  } {
    upgrade-tip termix-nu (query-ver $confName) $currentVer
  }
}

# Query and save termix-nu version to conf file everyday
def 'query-ver' [
  conf: string,
] {
  enter $nu.env.TERMIX_DIR; git fetch origin -p
  let latestVer = (git tag -l --sort=-v:refname | lines | nth 0)
  [[latestVer checkDate]; [$latestVer $checkDate]]  | to json --pretty 2 | save $conf
  echo $latestVer
}

# Compare min version with current version and show upgrading tips if required
def 'upgrade-tip' [
  cmd: string,
  min: string,
  current: string,
] {
  if (is-lower-ver $current $min) {
    if ($cmd == 'termix-nu') {
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
      $' -----> Your ($cmd) is (ansi r)OUTDATED(ansi reset), latest ver: ($min) <----- (char nl)'
      $'  Please run (ansi g)`just upgrade`(ansi reset) to upgrade to the latest version.(char nl)'
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
    } {
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
      $'  Min required ($cmd) ver: (ansi r)($min)(ansi reset), current ($cmd) ver: ($current)(char nl)'
      $'  ------------> Your ($cmd) is (ansi r)OUTDATED(ansi reset) <------------ (char nl)'
      $'  Please run (ansi g)`brew upgrade ($cmd)`(ansi reset) to upgrade to the latest.(char nl)'
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
      exit --now
    }
  } {}
}
