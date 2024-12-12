#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.
# Usage:
#   nu actions/setup.nu

use ../utils/common.nu [is-installed, is-lower-ver, hr-line, can-write]

const DEST_DIR = '/usr/local/bin/'

const ASSETS = {
  macos_x86_64: 'x86_64-apple-darwin',
  macos_aarch64: 'aarch64-apple-darwin',
  linux_x86_64: 'x86_64-unknown-linux-musl',
  linux_aarch64: 'aarch64-unknown-linux-musl',
}

const LATEST_META = 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell/latest.json'

export def main [dest: string = $DEST_DIR] {
  let platform = $'($nu.os-info.name)_($nu.os-info.arch)'
  let current = get-versions
  let latest = get-latest-versions
  print $'(ansi g)Current versions:(ansi reset)'; hr-line 35; $current | print
  print $'(ansi g)Latest versions:(ansi reset)'; hr-line 35; $latest | print

  for bin in [nu] {
    if (is-lower-ver ($current | get $bin) ($latest | get $bin)) {
      install-or-update $bin $platform $dest
    } else {
      print $'(ansi g)($bin) is updated ...(ansi reset)'
    }
  }
}

export def get-versions [] {
  mut versions = {}
  for bin in [nu] {
    if not (is-installed $bin) { $versions = $versions | upsert $bin '0.0.0' } else {
      let version = ^$'($bin)' --version
      $versions = $versions | upsert $bin $version
    }
  }
  $versions
}

export def get-latest-versions [] {
  mut versions = {}
  for bin in [nu] {
    let version = http get $LATEST_META | get version | str replace 'v' ''
    $versions = $versions | upsert $bin $version
  }
  $versions
}

export def install-or-update [bin platform dest] {
  print $'Installing or updating (ansi g)($bin) to ($dest) ...(ansi reset)'
  let latest = http get $LATEST_META
  let assetName = $latest | get assets | where name =~ ($ASSETS | get $platform) | get 0.name
  let pkg = $'/tmp/($assetName)'
  http get ($LATEST_META | str replace latest.json $assetName) | save -rpf $pkg
  try {
    # Don't use sudo if write permission allowed
    if not (can-write $dest) and (is-installed sudo) {
      sudo tar xzf $pkg -C $dest
      sudo mv ($'($dest)/nu-*/nu*' | into glob) $dest
    } else {
      tar xzf $pkg -C $dest
      mv ($'($dest)/nu-*/nu*' | into glob) $dest
    }
    rm $pkg
  } catch { |error|
    print $'(ansi r)Failed to install ($bin), due to the error: ($error.msg)(ansi reset)'
    exit 1
  }
  print $'Successfully installed (ansi g)($bin)@($latest.version)(ansi reset)'
}
