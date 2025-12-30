#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/12/11 09:39:56
# Description: Setup termix-nu on macOS or Linux.
# Usage:
#   nu actions/setup.nu

use ../utils/common.nu [is-installed, is-lower-ver, hr-line, can-write, set-dot-conf]

# Default binary installation directory
const DEST_DIR = '/usr/local/bin/'

# $'($nu.os-info.name)_($nu.os-info.arch)' --> Bin Name --> Asset keywords
const ASSETS = {
  macos_aarch64: {
    just: 'aarch64-darwin',
    fzf: 'aarch64-apple-darwin',
    nu: 'aarch64-apple-darwin',
    s5cmd: 'aarch64-apple-darwin',
  },
  macos_x86_64: {
    just: 'x86_64-darwin',
    fzf: 'x86_64-apple-darwin',
    nu: 'x86_64-apple-darwin',
    s5cmd: 'x86_64-apple-darwin',
  },
  linux_aarch64: {
    just: 'aarch64-linux-musl',
    fzf: 'aarch64-unknown-linux',
    nu: 'aarch64-unknown-linux-musl',
    s5cmd: 'aarch64-unknown-linux',
  },
  linux_x86_64: {
    just: 'x86_64-linux-musl',
    fzf: 'x86_64-unknown-linux',
    nu: 'x86_64-unknown-linux-musl',
    s5cmd: 'x86_64-unknown-linux',
  },
}

# Latest binary meta data from Aliyun OSS
const LATEST_META = {
  nu: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/nushell/latest.json',
  fzf: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/fzf/latest.json',
  just: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/just/latest.json',
  s5cmd: 'https://terminus-new-trantor.oss-cn-hangzhou.aliyuncs.com/open-tools/s5cmd/latest.json',
}

# Install or update nushell, fzf, and just to $DEST_DIR
export def setup-termix [
  dest: string = $DEST_DIR,   # Installation directory, default to $DEST_DIR
  --all(-a),                  # Upgrade all tools, including termix-nu
  --in-place-update(-u),      # Replace the current binary(if installed) with the latest version
] {
  let platform = $'($nu.os-info.name)_($nu.os-info.arch)'
  let current = get-versions
  let latest = get-latest-versions
  print $'(ansi g)Current version:(ansi rst)'; hr-line 35; $current | table -t psql | print
  print $'(ansi g)(char nl)Latest version:(ansi rst)'; hr-line 35; $latest | table -t psql | print
  print -n (char nl)

  for bin in ($LATEST_META | columns) {
    if (is-lower-ver ($current | get $bin) ($latest | get $bin)) {
      install-or-update $bin $platform $dest --in-place-update=$in_place_update
    } else {
      print $'(ansi g)($bin) is already updated ...(ansi rst)'
    }
  }
  if $all { upgrade-termix-nu }
  set-dot-conf installMethod setup
}

# Upgrade termix-nu script source repo
export def upgrade-termix-nu [] {
  print $'(char nl)Upgrading termix-nu...'; hr-line
  if 'TERMIX_DIR' in $env { cd $env.TERMIX_DIR } else {
    print $'Please set (ansi g)TERMIX_DIR(ansi rst) environment variable in (ansi g).env(ansi rst) to upgrade termix-nu'; return
  }

  # Fetch all tags and branches
  git fetch origin --tags --force
  git checkout master
  let tags = git tag -l --sort=-v:refname | lines
  if ($tags | is-empty) { print -e $'(ansi r)No tags found, upgrade skipped.(ansi rst)'; return }
  git reset --hard $tags.0
}

# Get current installed versions of nushell, fzf, and just
export def get-versions [] {
  mut versions = {}
  for bin in ($LATEST_META | columns) {
    if not (is-installed $bin) { $versions = $versions | upsert $bin '0.0.0' } else {
      let version = match $bin {
        fzf => { fzf --version | split row ' ' | first }
        just => { just --version | split row ' ' | last }
        s5cmd => { s5cmd version | split row - | first | str trim -c v },
        _ => { ^$'($bin)' --version }
      }
      $versions = $versions | upsert $bin $version
    }
  }
  $versions
}

# Get latest versions of nushell, fzf, and just from meta data
export def get-latest-versions [] {
  mut versions = {}
  for bin in ($LATEST_META | columns) {
    let version = http get ($LATEST_META | get $bin) | get version | str replace 'v' ''
    $versions = $versions | upsert $bin $version
  }
  $versions
}

# Install or update a binary to $DEST_DIR
export def install-or-update [
  bin: string,           # Binary name, e.g. 'nu', 'fzf', 'just', 's5cmd'
  platform: string,      # Platform name, e.g. 'macos_x86_64', 'linux_aarch64'
  dest: string,          # Installation directory, default to $DEST_DIR
  --in-place-update,     # Replace the current binary(if installed) with the latest version
] {
  let latestUrl = $LATEST_META | get $bin
  let latest = http get $latestUrl
  let assetName = $latest | get assets | where name =~ ($ASSETS | get $platform | get $bin) | get 0.name
  let pkg = $'/tmp/($assetName)'
  http get ($latestUrl | str replace latest.json $assetName) | save -rpf $pkg
  try {
    unzip-pkg $bin $pkg $dest --in-place-update=$in_place_update
  } catch { |error|
    print -e $'(ansi r)Failed to install ($bin), due to the error: ($error.msg)(ansi rst)'
    exit 1
  }
  print $'Successfully installed (ansi g)($bin)@($latest.version)(ansi rst)'
}

# Unzip a binary package to $DEST_DIR
def unzip-pkg [
  bin: string,          # Binary name, e.g. 'nu', 'fzf', 'just'
  pkg: string,          # Binary package file path
  dest: string,         # Installation directory, default to $DEST_DIR
  --in-place-update,    # Replace the current binary(if installed) with the latest version
] {
  let replace = $in_place_update and (is-installed $bin)
  let dest = if $replace { (which $bin).path.0 | path dirname } else { $dest }
  print $'Installing or updating (ansi g)($bin) to ($dest) ...(ansi rst)'

  let action = {|bin, sudo?|
      if $sudo == 'sudo' {
        match $bin {
          # Install just binary only without other assets
          just => { sudo tar xzf $pkg -C $dest just },
          nu => {
            sudo tar xzf $pkg -C $dest
            sudo mv ($'($dest)/nu-*/nu*' | into glob) $dest
            sudo rm -rf ($'($dest)/nu-*' | into glob)
          },
          _ => { sudo tar xzf $pkg -C $dest },
        }
        return
      }
      match $bin {
        # Install just binary only without other assets
        just => { tar xzf $pkg -C $dest just },
        nu => {
          tar xzf $pkg -C $dest
          mv ($'($dest)/nu-*/nu*' | into glob) $dest
          rm -rf ($'($dest)/nu-*' | into glob)
        },
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

alias main = setup-termix
