#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/12/16 16:06:56
# Description:
#   Doctor for termix-nu, Try to diagnose and fix common problems of termix-nu.
# TODO:
#   [√] Checking TERMIX_DIR environment variable
#   [√] Checking Nushell plugin path and version
#   [√] Registering Nushell plugins if plugin register file not found
#   [√] Checking Nu config file existence
#   [√] Checking macOS version
#   [√] Checking nu --version
#   [√] Checking just --version
#   [√] Checking fzf --version
#   [√] Checking termix-nu version
#   [√] Checking package-tools version
#   [?] Erda User name and password check
#   [x] `t` alias check

use upgrade.nu [upgrade-tool]
use setup.nu [get-versions, get-latest-versions]
use ../utils/common.nu [hr-line, windows?, is-lower-ver, get-conf, is-installed]

const STATUS = {
  OK: 'OK',
  WARN: 'WARN',
  ERROR: 'ERROR'
}

# Terminus npm registry
const REGISTRY = 'https://registry.npm.terminus.io'

# Try to diagnose and fix common problems of termix-nu
export def termix-doctor [
  --fix(-f),    # Try to fix the problem automatically
  --debug(-d),  # Show debug information
] {
  check-env 'Checking $TERMIX_DIR ...'        --fix=$fix --debug=$debug | show-result
  check-config 'Checking Nu config ...'       --fix=$fix --debug=$debug | show-result
  check-plugins 'Checking plugins ...'        --fix=$fix --debug=$debug | show-result
  check-macOS 'Checking macOS version ...'    --fix=$fix --debug=$debug | show-result
  check-bin 'Checking dependency version ...' --fix=$fix --debug=$debug | show-result
  check-termix 'Checking termix version ...'  --fix=$fix --debug=$debug | show-result
  check-pkg-tool 'Checking package-tools ...' --fix=$fix --debug=$debug | show-result
  if $fix { print -n (char nl); print $'(ansi g)如果执行 `--fix` 后仍有问题可以尝试重启终端(ansi rst)' }
  # check-alias 'Checking `t` alias ...'      --fix=$fix --debug=$debug | show-result
}

# Check TERMIX_DIR environment variable
def check-env [description: string, --fix, --debug] {
  const FIX_TIP = $'请确保 (ansi g).env(ansi rst) 文件存在并且其中的 (ansi g)TERMIX_DIR(ansi rst) 指向 termix-nu 根目录'
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.ERROR }
  if $debug { show-debug ($env.TERMIX_DIR? | default '') }
  if 'TERMIX_DIR' not-in $env or not ($env.TERMIX_DIR | path exists) {
    $result.message = 'TERMIX_DIR not set or invalid'
    return $result
  }
  cd $env.TERMIX_DIR
  if ([termix.toml Justfile .termixrc-example] | all { path exists }) {
    return { status: $STATUS.OK }
  }
  $result.message = '$TERMIX_DIR invalid'
  $result
}

# Checking Nushell config file existence
def check-config [description: string, --fix, --debug] {
  const FIX_TIP = $"请通过(ansi g) t doctor --fix (ansi rst)修复, 并重启终端"
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.ERROR }
  if $debug { show-debug $nu.default-config-dir }
  if ($nu.default-config-dir | path exists) { return { status: $STATUS.OK } }
  if $fix { mkdir $nu.default-config-dir; check-config 'Recheck .. ' | show-result; return }
  $result.message = $'($nu.default-config-dir) dir does not exist'
  $result
}

# Check Nushell plugins
def check-plugins [description: string, --fix, --debug] {
  const FIX_TIP = $"请通过(ansi g) nu -c 'rm $nu.plugin-path' (ansi rst)或(ansi g) t doctor --fix (ansi rst)修复, 并重启终端"
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.ERROR }
  if not ($nu.plugin-path | path exists) { register-plugins }
  let plugins = open $nu.plugin-path
  let actualVer = ^$nu.current-exe -v | str trim
  let nuVersion = $plugins.nushell_version
  let allPlugins = $plugins | get plugins | select filename metadata.version
  let versionMatch = $allPlugins | all {|it| ($it | get 'metadata.version') == $nuVersion }
  let pluginExists = $allPlugins | all {|it| $it.filename | path exists }
  if $debug {
    show-debug { version: $actualVer, registered: $nuVersion, allPlugins: $allPlugins }
  }
  if $versionMatch and $pluginExists and ($actualVer == $nuVersion) { return { status: $STATUS.OK } }
  if $fix { nu -c 'rm $nu.plugin-path'; register-plugins; check-plugins 'Recheck .. ' | show-result; return }
  $result.message = 'Plugins not found or version mismatch'
  $result
}

# Check macOS version
def check-macOS [description: string, --fix, --debug] {
  if $nu.os-info.name != 'macos' { return }
  const FIX_TIP = '建议升级到最新版本的 macOS'
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.WARN }
  let macOSVersion = sys host | get os_version
  if $debug { show-debug $macOSVersion }
  if ($macOSVersion | split row . | first | into int) < 13 {
    $result.message = 'macOS outdated'
    return $result
  }
  { status: $STATUS.OK }
}

# Check binary dependencies versions, such as nu, just, fzf, etc.
def check-bin [description: string, --fix, --debug] {
  const FIX_TIP = $"请通过(ansi g) t upgrade -a (ansi rst)进行升级, 并重启终端"
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.WARN }
  let current = get-versions
  let latest = get-latest-versions
  # Get outdated binary dependencies
  let outdated = $current | columns | reduce -f [] {|it, acc|
    if (is-lower-ver ($current | get $it) ($latest | get $it)) { ($acc | default []) ++ [$it] }
  }
  if $debug {
    show-debug { current: $current, latest: $latest, outdated: $outdated }
  }
  if ($outdated | is-empty) { return { status: $STATUS.OK } }
  if $fix { upgrade-tool --all; check-bin 'Recheck .. ' | show-result; return }
  $result.message = $'Outdated binary dependencies: ($outdated | str join ", ")'
  $result
}

# Check termix-nu version
def check-termix [description: string, --fix, --debug] {
  cd $env.TERMIX_DIR
  const FIX_TIP = $'请通过(ansi g) t upgrade -a (ansi rst)进行升级, 并重启终端'
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.WARN }
  let current = get-conf version
  let latest = if ($env.DISABLE_VERSION_CHECK? | default false | into bool) { $current } else {
      do -i { git pull --tags --force | ignore; (git tag -l --sort=-v:refname | lines | select 0).0 }
    }
  if $debug { show-debug { current: $current, latest: $latest } }
  if not (is-lower-ver $current $latest) { return { status: $STATUS.OK } }
  if $fix { upgrade-tool; check-termix 'Recheck .. ' | show-result; return }
  $result.message = $'Termix-nu outdated, current: ($current), latest: ($latest)'
  $result
}

# Check package-tools version
def check-pkg-tool [description: string, --fix, --debug] {
  if not (is-installed package-tools) { return }
  const FIX_TIP = $'请通过(ansi g) npm i -g @terminus/t-package-tools@latest --registry ($REGISTRY) (ansi rst)进行升级'
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.WARN }
  let current = package-tools --version
  let latest = http get $'($REGISTRY)/@terminus/t-package-tools' | get dist-tags.latest
  if $debug { show-debug { current: $current, latest: $latest } }
  if not (is-lower-ver $current $latest) { return { status: $STATUS.OK } }
  if $fix { upgrade-package-tools; check-pkg-tool 'Recheck .. ' | show-result; return }
  $result.message = $'Package-tools outdated, current: ($current), latest: ($latest)'
  $result
}

# Check `t` alias
def check-alias [description: string, --fix, --debug] {
  const FIX_TIP = '请为 termix-nu 设置 `t` 别名'
  print -n $description
  mut result = { tip: $FIX_TIP, status: $STATUS.WARN }
  let typeT = try {
      # FIXME: This command may not work due to the shell haven't sourced yet.
      ^$env.SHELL -c 'type -t t 2>/dev/null || echo "NOT_EXIST"'
    } catch {
      which t | get -o type?.0? | default 'NOT_EXIST'
    }
  if $debug { show-debug $'Type of `t`: ($typeT)' }
  if $typeT == 'NOT_EXIST' {
    $result.message = 't alias not found'
    return $result
  }
  { status: $STATUS.OK }
}

# Register Nushell plugins
def register-plugins [] {
  let nuDir = $nu.current-exe | path dirname
  [nu_plugin_query nu_plugin_polars nu_plugin_gstat nu_plugin_inc nu_plugin_formats] | each {|it|
    if (windows?) {
      nu -c $"plugin add '($nuDir)/($it).exe'"
    } else {
      nu -c $"plugin add '($nuDir)/($it)'"
    }
  }
}

# Upgrade @terminus/t-package-tools
def upgrade-package-tools [] {
  let npmModules = npm ls -g --json | from json | get dependencies? | default {} | columns
  let installedByNpm = '@terminus/t-package-tools' in $npmModules
  if $installedByNpm {
    npm i -g @terminus/t-package-tools@latest --registry $REGISTRY
    return
  }
  if (is-installed pnpm) and (pnpm ls -g @terminus/t-package-tools --json | from json | get -o dependencies.0 | is-not-empty) {
    pnpm i -g @terminus/t-package-tools@latest --registry $REGISTRY
    return
  }
  print -e "Sorry, I can't fix it, please fix it yourself."
}

# Show diagnostic result
def show-result [] {
  if ($in | is-empty) { return }
  if $in.status == $STATUS.OK {
    print -n $'(ansi g)OK(ansi rst)(char nl)'; return
  }
  print -n (char nl); hr-line 80
  $in | select status message? tip | print
  print -n (char nl)
}

# Show debug information
def show-debug [data] { print -n (char nl); hr-line -c grey66; $data | table -e | print  }
