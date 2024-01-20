#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/13 15:20:20
# Updated: 2024/01/19 22:05:20
# Description: Script to speed up homebrew using CN mirrors
# REF:
#   - https://mirrors.ustc.edu.cn/help/brew.git.html
#   - https://mirrors.tuna.tsinghua.edu.cn/help/homebrew/
#   - https://developer.aliyun.com/mirror/homebrew
# TODO:
#   [√] Check brew install status
#   [√] Add USTC mirror support
#   [√] Add TUNA mirror support
#   [√] Add Aliyun mirror support
#   [√] Switch between all the mirrors
# Usage:
#   Install homebrew: /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
# 	just fast-brew

use ../utils/common.nu [ECODE, is-installed, hr-line]

const TUNA_MIRROR = {
  HOMEBREW_PIP_INDEX_URL: 'https://pypi.tuna.tsinghua.edu.cn/simple',
  HOMEBREW_API_DOMAIN: 'https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api',
  HOMEBREW_BOTTLE_DOMAIN: 'https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles',
  HOMEBREW_BREW_GIT_REMOTE: 'https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git',
  HOMEBREW_CORE_GIT_REMOTE: 'https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git',
}

const USTC_MIRROR = {
  HOMEBREW_BREW_GIT_REMOTE: 'https://mirrors.ustc.edu.cn/brew.git',
  HOMEBREW_BOTTLE_DOMAIN: 'https://mirrors.ustc.edu.cn/homebrew-bottles',
  HOMEBREW_API_DOMAIN: 'https://mirrors.ustc.edu.cn/homebrew-bottles/api',
  HOMEBREW_CORE_GIT_REMOTE: 'https://mirrors.ustc.edu.cn/homebrew-core.git',
}

const ALIYUN_MIRROR = {
  HOMEBREW_API_DOMAIN: 'https://mirrors.aliyun.com/homebrew-bottles/api',
  HOMEBREW_BREW_GIT_REMOTE: 'https://mirrors.aliyun.com/homebrew/brew.git',
  HOMEBREW_BOTTLE_DOMAIN: 'https://mirrors.aliyun.com/homebrew/homebrew-bottles',
  HOMEBREW_CORE_GIT_REMOTE: 'https://mirrors.aliyun.com/homebrew/homebrew-core.git',
}

# A wrapper for homebrew, which can switch between all the China mirrors
export def --wrapped fast-brew [
  --tuna,     # Use TUNA mirror
  --aliyun,   # Use Aliyun mirror
  ...rest,    # Other brew commands and options
] {
  if not (is-installed brew) {
    print $'(ansi p)Homebrew is not installed, please install it by running:(ansi reset)'; hr-line
    print '/bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"'
    print -n (char nl)
    exit $ECODE.MISSING_BINARY
  }
  let MIRROR = if $tuna { $TUNA_MIRROR } else if $aliyun { $ALIYUN_MIRROR } else { $USTC_MIRROR }
  load-env $MIRROR
  # Tapping homebrew/cask is no longer typically necessary.
  # brew tap --custom-remote --force-auto-update homebrew/cask https://mirrors.ustc.edu.cn/homebrew-cask.git
  # Disable the following taps for prebuild binary install
  # brew tap --custom-remote --force-auto-update homebrew/services https://mirrors.ustc.edu.cn/homebrew-services.git
  # brew tap --custom-remote --force-auto-update homebrew/cask-versions https://mirrors.ustc.edu.cn/homebrew-cask-versions.git

  brew ...$rest
  # reset-official
}

def reset-official [] {
  git -C (brew --repo) remote set-url origin https://github.com/Homebrew/brew
  git -C (brew --repo homebrew/core) remote set-url origin https://github.com/Homebrew/homebrew-core
  brew tap --custom-remote homebrew/cask https://github.com/Homebrew/homebrew-cask
  brew tap --custom-remote homebrew/services https://github.com/Homebrew/homebrew-services
  brew tap --custom-remote homebrew/cask-versions https://github.com/Homebrew/homebrew-cask-versions
}
