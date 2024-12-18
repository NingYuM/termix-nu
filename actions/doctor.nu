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
#   [ ] Checking termix-nu version
#   [ ] Checking package-tools version
#   [ ] Erda User name and password check
#   [ ] `t` alias check

use upgrade.nu [upgrade-tool]
use setup.nu [get-versions, get-latest-versions]
use ../utils/common.nu [hr-line, windows?, is-lower-ver]

const STATUS = {
  OK: 'OK',
  WARN: 'WARN',
  ERROR: 'ERROR'
}

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
}

# Check TERMIX_DIR environment variable
def check-env [description: string, --fix, --debug] {
  const FIX_TIP = '请确保 .env 文件存在并且其中的 TERMIX_DIR 指向 termix-nu 根目录'
  print -n $description
  mut result = {
    tip: $FIX_TIP,
    status: $STATUS.ERROR,
  }
  if $debug { print -n (char nl); hr-line -c grey66; print ($env.TERMIX_DIR? | default '') }
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
  const FIX_TIP = $"请通过(ansi g) t doctor --fix (ansi reset)修复, 并重启终端"
  print -n $description
  mut result = {
    tip: $FIX_TIP,
    status: $STATUS.ERROR,
  }
  if $debug { print -n (char nl); hr-line -c grey66; print $nu.default-config-dir }
  if $fix and not ($nu.default-config-dir | path exists) { mkdir $nu.default-config-dir }
  if not ($nu.default-config-dir | path exists) {
    $result.message = $'($nu.default-config-dir) dir does not exist'
    return $result
  }
  { status: $STATUS.OK }
}

# Check Nushell plugins
def check-plugins [description: string, --fix, --debug] {
  const FIX_TIP = $"请通过(ansi g) nu -c 'rm $nu.plugin-path' (ansi reset)或(ansi g) t doctor --fix (ansi reset)修复, 并重启终端"
  print -n $description
  mut result = {
    tip: $FIX_TIP,
    status: $STATUS.ERROR,
  }
  if not ($nu.plugin-path | path exists) { register-plugins }
  let plugins = open $nu.plugin-path
  let nuVersion = $plugins.nushell_version
  let allPlugins = $plugins | get plugins | select filename metadata.version
  let versionMatch = $allPlugins | all {|it| ($it | get 'metadata.version') == $nuVersion }
  let pluginExists = $allPlugins | any {|it| $it.filename | path exists }
  if $debug {
    print -n (char nl); hr-line -c grey66
    { nuVersion: $nuVersion, allPlugins: $allPlugins } | table -e | print
  }
  if $versionMatch and $pluginExists { return { status: $STATUS.OK } }
  $result.message = 'Plugins not found or version mismatch'
  if $fix { nu -c 'rm $nu.plugin-path'; register-plugins }
  $result
}

# Check macOS version
def check-macOS [description: string, --fix, --debug] {
  if $nu.os-info.name != 'macos' { return }
  const FIX_TIP = '建议升级到最新版本的 macOS'
  print -n $description
  mut result = {
    tip: $FIX_TIP,
    status: $STATUS.WARN,
  }
  let macOSVersion = sys host | get os_version
  if $debug { print -n (char nl); hr-line -c grey66; print $macOSVersion }
  if ($macOSVersion | split row . | first | into int) < 13 {
    $result.message = 'macOS outdated'
    return $result
  }
  { status: $STATUS.OK }
}

# Check binary dependencies versions, such as nu, just, fzf, etc.
def check-bin [description: string, --fix, --debug] {
  const FIX_TIP = $"请通过(ansi g) t upgrade -a (ansi reset)进行升级, 并重启终端"
  print -n $description
  mut result = {
    tip: $FIX_TIP,
    status: $STATUS.WARN,
  }
  let current = get-versions
  let latest = get-latest-versions
  # Get outdated binary dependencies
  let outdated = $current | columns | reduce -f [] {|it, acc|
    if (is-lower-ver ($current | get $it) ($latest | get $it)) { $acc ++ [$it] }
  }
  if $debug {
    print -n (char nl); hr-line -c grey66
    { current: $current, latest: $latest, outdated: $outdated } | table -e | print
  }
  if ($outdated | is-empty) { return { status: $STATUS.OK } }
  if $fix { upgrade-tool --all }
  $result.message = $'Outdated binary dependencies: ($outdated | str join ", ")'
  $result
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

# Show diagnostic result
def show-result [] {
  if ($in | is-empty) { return }
  if $in.status == $STATUS.OK {
    print -n $'(ansi g)OK(ansi reset)(char nl)'; return
  }
  print -n (char nl); hr-line 80
  $in | select status message? tip | print
  print -n (char nl)
}
