#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/13 15:20:20
# Description: Script to speed up homebrew using CN mirrors
# TODO:
# [ ] Check brew install status
# [√] 备份原始地址到 prev remote
# [√] 支持还原 origin 到最初设置
# Usage:
# 	just brew-speed-up

use ../utils/common.nu [hr-line]

export def main [
  status: string  # set to `off` to disable brew speed up
] {

  let BREW_MIRROR = 'https://mirrors.aliyun.com/homebrew/brew.git'
  let CASK_MIRROR = 'https://mirrors.ustc.edu.cn/homebrew-cask.git'
  let CORE_MIRROR = 'https://mirrors.aliyun.com/homebrew/homebrew-core.git'
  let brewRepo = (brew --repo | str trim)
  let brewCore = ($brewRepo | path join 'Library/Taps/homebrew/homebrew-core')
  let brewCask = ($brewRepo | path join 'Library/Taps/homebrew/homebrew-cask')
  if ($status == 'off') {
    print $'(ansi p)Restore original brew related git remote urls:(ansi reset)(char nl)'
    restore-origin $brewRepo
    restore-origin $brewCore
    restore-origin $brewCask
  } else {
    print $'(ansi p)Going to speed up homebrew using mirrors:(ansi reset)(char nl)'
    backup-origin $brewRepo $BREW_MIRROR
    backup-origin $brewCore $CORE_MIRROR
    backup-origin $brewCask $CASK_MIRROR
  }
  # Current shell: $env.SHELL
  print $'Update brew config successfully, latest config:(char nl)'
  hr-line; brew config; hr-line
  if ($status == 'off') {
    print $'(ansi r)如果当前 Shell 配置文件（通常为~/.zshrc 或 ~/.bashrc）中包含 "export HOMEBREW_BOTTLE_DOMAIN=xx" 请将其删除(ansi reset)'
    print $'(char nl)删除完毕记得执行 source 命令, eg: `source ~/.bashrc` 使最新配置生效!(char nl)'
  } else {
    print $'(ansi r)尚需手工将以下内容添加到当前 Shell 配置文件（通常为~/.zshrc 或 ~/.bashrc）中:(ansi reset)(char nl)'
    print $'export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.aliyun.com/homebrew/homebrew-bottles'
    print $'(char nl)添加完毕记得执行 source 命令, eg: `source ~/.bashrc` 使最新配置生效!(char nl)'
  }
}

# Backup and then update the origin url to a mirror url
def 'backup-origin' [
  dir: string
  mirrorUrl: string
] {
  cd $dir
  # Backup the initial origin url to prev remote
  if (git remote -v | find prev) == '' {
    let origin = (git remote get-url origin | str trim)
    print $'(ansi g)Backup origin url ($origin) to remote ‘prev’(ansi reset)(char nl)'
    git remote add prev $origin
  }
  git remote set-url origin $mirrorUrl
}

# Restore the origin url from backup of prev
def 'restore-origin' [
  dir: string
] {
  cd $dir
  # Do nothing if we can not find a backup
  if (git remote -v | find prev) == '' {
    let baseName = ($dir | path basename)
    print $'(ansi r)Can not find a remote backup for ($baseName), nothing to restore...(ansi reset)(char nl)'
  } else {
    git remote set-url origin (git remote get-url prev | str trim)
  }
}
