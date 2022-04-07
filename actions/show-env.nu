#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/04 13:06:56
# Usage:
#   t show-env

# Show locally installed cli app's version and env infomation
def 'show-env' [] {
  let termixDir = (get-env TERMIX_DIR '(empty)')
  let shell = (get-env SHELL_TO_RUN_CMD '(empty)')
  let justFile = (get-env JUST_FILE_PATH '(empty)')
  let termixTmp = (get-env TERMIX_TMP_PATH '(empty)')
  let justInvokeDir = (get-env JUST_INVOKE_DIR '(empty)')
  let syncIgnore = (get-env SYNC_IGNORE_ALIAS '(empty)')
  let npmVer = (get-ver npm 'npm --version')
  let yarnVer = (get-ver yarn 'yarn --version')
  let herdVer = (get-ver herd 'herd --version')
  let termixVer = (get-ver termix 'termix --version')
  let nodeVer = (get-ver node '(node --version | str substring '1,')')
  let fnmVer = (get-ver fnm "fnm --version | str trim -b | str substring '4,'")
  let justVer = (get-ver just "just --version | str trim -b | str substring '5,'")
  let gitVer = (get-ver git "git --version | str trim -b | str substring '12,'")
  let time = (date now | date format '%Y/%m/%d %H:%M:%S')
  let gitProxy = (if (git config --global --list | grep proxy | empty?) { 'Off' } else { 'On' })

  version | transpose | rename nu-ver value

  # FIXME: Table layout will be broken on Windows if using `echo` here
  print [
    [name, value];
    ['Git', $gitVer]
    ['Fnm', $fnmVer]
    ['Just', $justVer]
    ['Herd', $herdVer]
    ['Node', $nodeVer]
    ['Npm', $npmVer]
    ['Yarn', $yarnVer]
    ['Termix', $termixVer]
    ['-------', '--------']
    ['Git Proxy', $gitProxy]
    ['SHELL_TO_RUN_CMD', $shell]
    ['SYNC_IGNORE_ALIAS', $syncIgnore]
    ['JUST_FILE', $justFile]
    ['TERMIX_TMP_PATH', $termixTmp]
    ['TERMIX_DIR', $termixDir]
    ['JUST_INVOKE_DIR', $justInvokeDir]
    ['Current Time', $time]
  ]
}
