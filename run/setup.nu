#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.
# Usage:
#   nu actions/setup.nu

use ../utils/common.nu [is-installed, is-lower-ver, hr-line, can-write]

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

export def main [dest: string = $DEST_DIR] {
  let platform = $'($nu.os-info.name)_($nu.os-info.arch)'
  let current = get-versions
  let latest = get-latest-versions
  print $'(ansi g)Current version:(ansi reset)'; hr-line 35; $current | table -t psql | print
  print $'(ansi g)(char nl)Latest version:(ansi reset)'; hr-line 35; $latest | table -t psql | print
  print -n (char nl)

  for bin in ($LATEST_META | columns) {
    if (is-lower-ver ($current | get $bin) ($latest | get $bin)) {
      install-or-update $bin $platform $dest
    } else {
      print $'(ansi g)($bin) is already updated ...(ansi reset)'
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

export def install-or-update [bin platform dest] {
  print $'Installing or updating (ansi g)($bin) to ($dest) ...(ansi reset)'
  let latestUrl = $LATEST_META | get $bin
  let latest = http get $latestUrl
  let assetName = $latest | get assets | where name =~ ($ASSETS | get $platform | get $bin) | get 0.name
  let pkg = $'/tmp/($assetName)'
  http get ($latestUrl | str replace latest.json $assetName) | save -rpf $pkg
  try {
    unzip-pkg $bin $pkg $dest
  } catch { |error|
    print $'(ansi r)Failed to install ($bin), due to the error: ($error.msg)(ansi reset)'
    exit 1
  }
  print $'Successfully installed (ansi g)($bin)@($latest.version)(ansi reset)'
}

def unzip-pkg [bin pkg dest] {
  let action = {|bin, sudo?|
      if $sudo == 'sudo' {
        match $bin {
          # Install just binary only without other assets
          just => { sudo tar xzf $pkg -C $dest just },
          nu => { sudo tar xzf $pkg -C $dest; mv ($'($dest)/nu-*/nu*' | into glob) $dest },
          _ => { sudo tar xzf $pkg -C $dest },
        }
        return
      }
      match $bin {
        # Install just binary only without other assets
        just => { tar xzf $pkg -C $dest just },
        nu => { tar xzf $pkg -C $dest; mv ($'($dest)/nu-*/nu*' | into glob) $dest },
        _ => { tar xzf $pkg -C $dest },
      }
    }

  # Don't use sudo if write permission allowed
  if not (can-write $dest) and (is-installed sudo) {
    do $action $bin sudo
  } else {
    do $action $bin
  }
  rm $pkg
}
