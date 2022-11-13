#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/14 10:06:56
# Description: Check the current nushell version
# Usage:
#   nu-ver

# Check min nushell version and show upgrading tips to the user
export def 'nu-ver' [] {

  let currentVer = (version).version
  let minVer = get-conf minNuVer '0.71.0'
  upgrade-tip nushell $minVer $currentVer
}

# Check min just version and show upgrading tips to the user
export def 'just-ver' [] {

  let currentVer = (just --version | str replace 'just' '' | str trim | first)
  let minVer = get-conf minJustVer '1.8.0'
  upgrade-tip just $minVer $currentVer
}

# Force Upgrade Test Case:
# [√] 兼容老的配置项: 没有 forceUpgrade 配置项时正常执行;
# [√] 发布**非强制更新新版本**的时候不升级的情况下可以正常执行当前命令;
# [√] 发布新的强制更新版本时：
#     [√] 可以检测到并在第二次执行命令时强制更新否则退出;
#     [√] 当用户升级到最新版本后所有命令可以正常执行；
#     [√] 当删除掉最新的强制更新版本 Release Tag 时用户端可以检测到并在不升级的情况下恢复正常使用；
# Check latest termix-nu version and show upgrading tips if there is a new release
export def 'termix-ver' [] {
  # FIXME
  let _DATE_FMT = _DATE_FMT
  let tmpPath = get-tmp-path
  let currentVer = get-conf version
  let confName = ([$tmpPath '.termix-conf'] | path join)
  let checkDate = (date now | date format $_DATE_FMT)
  if ($confName | path exists) {
    let conf = open -r $confName
    let latestVer = ($conf | query json 'latestVer')
    if ($conf | query json 'checkDate') == $checkDate {
      upgrade-tip termix-nu $latestVer $currentVer
    } else {
      upgrade-tip termix-nu (query-ver $confName) $currentVer
    }

    # Parse conf as JSON and check forceUpgrade column
    let hasForceUpgrade = ($conf | query json forceUpgrade) != $nothing
    let forceUpgrade = (if $hasForceUpgrade { ($conf | query json 'forceUpgrade') && (is-lower-ver $currentVer $latestVer)} else { false })
    # Quit command right now if it's a force upgrade
    if ($forceUpgrade) {
      $'(ansi r)很抱歉，为了更好地为您提供服务请先更新 termix-nu 并重试...(ansi reset)(char nl)(char nl)'
      (query-ver $confName | ignore); exit 1 --now    # Query and update latest version again.
    }
    if (not $hasForceUpgrade) {
      query-ver $confName | ignore
    }
  } else {
    upgrade-tip termix-nu (query-ver $confName) $currentVer
  }
}

# Query and save termix-nu version to conf file everyday
def 'query-ver' [
  conf: string,
] {
  # FIXME
  let _DATE_FMT = _DATE_FMT
  # FIXME
  let _UPGRADE_TAG = _UPGRADE_TAG
  # Update latest commits from remote to local, tags inclueded
  enter $env.TERMIX_DIR; git fetch origin -p
  let checkDate = (date now | date format $_DATE_FMT)
  # Get latest release tag name
  let latestVer = (git tag -l --sort=-v:refname | lines | select 0).0
  # Check whether the latest release tag is a force upgrade
  let msg = git show --oneline --no-patch $latestVer
  let forceUpgrade = ($msg | str contains $_UPGRADE_TAG)
  let config = { 'latestVer': $latestVer, 'checkDate': $checkDate, 'forceUpgrade': $forceUpgrade }
  $config | to json | save $conf
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
    } else {
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
      $'  Min required ($cmd) ver: (ansi r)($min)(ansi reset), current ($cmd) ver: ($current)(char nl)'
      $'  ------------> Your ($cmd) is (ansi r)OUTDATED(ansi reset) <------------ (char nl)'
      $'  Please run (ansi g)`brew upgrade ($cmd)`(ansi reset) to upgrade to the latest.(char nl)'
      $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
      exit --now
    }
  }
}
