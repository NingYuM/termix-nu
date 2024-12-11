#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.
# Usage:
#   nu actions/setup.nu

use ../utils/common.nu [is-installed, is-lower-ver, hr-line]

const DEST_DIR = '/usr/local/bin/'

const ASSETS = {
  macos_aarch64: {
    just: 'aarch64-darwin',
    fzf: 'aarch64-apple-darwin',
    nushell: 'aarch64-apple-darwin',
  },
  macos_x86_64: {
    just: 'x86_64-darwin',
    fzf: 'x86_64-apple-darwin',
    nushell: 'x86_64-apple-darwin',
  },
  linux_aarch64: {
    just: 'aarch64-linux-musl',
    fzf: 'aarch64-unknown-linux',
    nushell: 'aarch64-unknown-linux-musl',
  },
  linux_x86_64: {
    just: 'x86_64-linux-musl',
    fzf: 'x86_64-unknown-linux',
    nushell: 'x86_64-unknown-linux-musl',
  },
}

const LATEST_META = {
  nu: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell/latest.json',
  fzf: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/fzf/latest.json',
  just: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/just/latest.json',
}

export def main [] {
  let platform = $'($nu.os-info.name)_($nu.os-info.arch)'
  let current = get-versions
  let latest = get-latest-versions
  print $'(ansi g)Current versions:(ansi reset)'; hr-line 35; $current | print
  print $'(ansi g)Latest versions:(ansi reset)'; hr-line 35; $latest | print

  for bin in ($LATEST_META | columns) {
    if (is-lower-ver ($current | get $bin) ($latest | get $bin)) {
      install-or-update $bin $platform
    } else {
      print $'(ansi g)($bin) is updated ...(ansi reset)'
    }
  }
}

export def get-versions [] {
  mut versions = {}
  for bin in ($LATEST_META | columns) {
    if not (is-installed $bin) { $versions = $versions | upsert $bin '0.0.0' } else {
      let version = match $bin {
        fzf => { fzf --version | split row ' ' | first }
        just => { just --version | split row ' ' | last }
        _ => { ^$'($bin)' --version }
      }
      $versions = $versions | upsert $bin $version
    }
  }
  $versions
}

export def get-latest-versions [] {
  mut versions = {}
  for bin in ($LATEST_META | columns) {
    let version = http get ($LATEST_META | get $bin) | get version | str replace 'v' ''
    $versions = $versions | upsert $bin $version
  }
  $versions
}

export def install-or-update [bin platform] {
  print $'(ansi g)Installing or updating ($bin) ...(ansi reset)'
  let latestUrl = $LATEST_META | get $bin
  let latest = http get $latestUrl
  let assetName = $latest | get assets | where name =~ ($ASSETS | get $platform | get $bin) | get 0.name
  let pkg = $'/tmp/($assetName)'
  http get ($latestUrl | str replace latest.json $assetName) | save -rpf $pkg
  try {
    if (is-installed sudo) { sudo tar xzf $pkg -C $DEST_DIR } else { tar xzf $pkg -C $DEST_DIR }
    rm $pkg
  } catch { |error|
    print $'(ansi r)Failed to install ($bin), due to the error: ($error.msg)(ansi reset)'
    exit 1
  }
  print $'(ansi g)($bin) is installed successfully with version ($latest.version)(ansi reset)'
}
