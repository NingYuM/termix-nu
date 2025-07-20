#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/14 10:06:56
# Description: Check the current nushell version
# Usage:
#   nu-ver

use ../utils/common.nu [ECODE, _DATE_FMT, _UPGRADE_TAG, get-tmp-path, get-conf, is-lower-ver]

# Check min nushell version and show upgrading tips to the user
export def nu-ver [] {

  let currentVer = (version).version
  let minVer = get-conf minNuVer '0.105.0'
  upgrade-tip nushell $minVer $currentVer
}

# Check min just version and show upgrading tips to the user
export def just-ver [] {

  let currentVer = (just --version | str replace 'just' '' | str trim)
  let minVer = get-conf minJustVer '1.39.0'
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
export def termix-ver [] {
  let tmpPath = get-tmp-path
  let currentVer = get-conf version
  let confName = [$tmpPath '.termix-conf'] | path join
  let checkDate = date now | format date $_DATE_FMT
  if ($confName | path exists) {
    let conf = open -r $confName | from json
    let latestVer = $conf.latestVer?
    if $conf.checkDate? == $checkDate {
      upgrade-tip termix-nu $latestVer $currentVer
    } else {
      upgrade-tip termix-nu (query-ver $confName) $currentVer
    }

    # Parse conf as JSON and check forceUpgrade column
    let hasForceUpgrade = $conf.forceUpgrade? != null
    let forceUpgrade = (if $hasForceUpgrade { $conf.forceUpgrade? and (is-lower-ver $currentVer $latestVer) } else { false })
    # Quit command right now if it's a force upgrade
    if $forceUpgrade {
      print $'(ansi r)很抱歉，为了更好地为您提供服务请先执行 `just upgrade -a` 更新 termix-nu 并重试...(ansi rst)(char nl)(char nl)'
      (query-ver $confName | ignore); exit $ECODE.OUTDATED    # Query and update latest version again.
    }
    if not $hasForceUpgrade { query-ver $confName | ignore }
  } else {
    upgrade-tip termix-nu (query-ver $confName) $currentVer
  }
}

# Query and save termix-nu version to conf file everyday
def query-ver [
  conf: string,   # Termix-nu conf file path
] {
  # Update latest commits from remote to local, tags included
  cd $env.TERMIX_DIR
  if not ($env.DISABLE_VERSION_CHECK? | default false | into bool) {
    git fetch origin -p --tags --force | complete | ignore
  }
  let checkDate = date now | format date $_DATE_FMT
  let currentVer = get-conf version
  let versions = git tag -l --sort=-v:refname | lines
  let latestVer = $versions.0
  let newVersions = $versions | where {|it| is-lower-ver $currentVer $it }
  let forceUpgrade = $newVersions | any {|it| git show --oneline --no-patch $it | str contains $_UPGRADE_TAG }
  let config = { latestVer: $latestVer, checkDate: $checkDate, forceUpgrade: $forceUpgrade }
  if ($conf | path exists) {
    open $conf | from json | merge $config | to json | save -f $conf
  } else {
    $config | to json | save -f $conf
  }
  $latestVer
}

# Compare min version with current version and show upgrading tips if required
def upgrade-tip [
  cmd: string,       # Command or binary name
  min: string,       # Minimum required version read from termix.toml
  current: string,   # Current version of the command or binary
] {
  if (is-lower-ver $current $min) {
    if $cmd == 'termix-nu' {
      print $'(ansi g)───────────────────────────────────────────────────────────────────────────────(ansi rst)(char nl)'
      print $'        -----> Your ($cmd) is (ansi r)OUTDATED(ansi rst), latest ver: (ansi p)($min)(ansi rst) <----- (char nl)'
      print $'         Please run (ansi g)`just upgrade`(ansi rst) to upgrade to the latest version.(char nl)'
      print $'(ansi lpr)      You may need to run `t upgrade -a` to upgrade `nu` and `just`, too.      (ansi rst)'
      print $'(ansi g)───────────────────────────────────────────────────────────────────────────────(ansi rst)(char nl)'
    } else {
      print $'(ansi g)───────────────────────────────────────────────────────────────────────────────(ansi rst)(char nl)'
      print $'      Min required ($cmd) ver: (ansi r)($min)(ansi rst), current ($cmd) ver: ($current)(char nl)'
      print $'        ------------> Your ($cmd) is (ansi r)OUTDATED(ansi rst) <------------ (char nl)'
      print $'(ansi lpr)       Please run `t upgrade ($cmd)` to upgrade to the latest version.        (ansi rst)(char nl)'
      print $'(ansi g)───────────────────────────────────────────────────────────────────────────────(ansi rst)(char nl)'
    }
  }
}
