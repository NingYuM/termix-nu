#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/13 15:20:20
# Updated: 2024/01/19 22:05:20
# Description: Script to speed up homebrew using CN mirrors
# REF:
#   - https://mirrors.ustc.edu.cn/help/brew.git.html
# TODO:
# [ ] Check brew install status
# Usage:
#   Install homebrew: /bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"
# 	just fast-brew

use ../utils/common.nu [ECODE, is-installed, hr-line]

export def --wrapped fast-brew [
  ...rest
] {
  if not (is-installed brew) {
    print $'(ansi p)Homebrew is not installed, please install it by running:(ansi reset)'; hr-line
    print '/bin/bash -c "$(curl -fsSL https://mirrors.ustc.edu.cn/misc/brew-install.sh)"'
    print -n (char nl)
    exit $ECODE.MISSING_BINARY
  }
  load-env {
    HOMEBREW_BREW_GIT_REMOTE: 'https://mirrors.ustc.edu.cn/brew.git',
    HOMEBREW_BOTTLE_DOMAIN: 'https://mirrors.ustc.edu.cn/homebrew-bottles',
    HOMEBREW_API_DOMAIN: 'https://mirrors.ustc.edu.cn/homebrew-bottles/api',
    HOMEBREW_CORE_GIT_REMOTE: 'https://mirrors.ustc.edu.cn/homebrew-core.git',
  }
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
