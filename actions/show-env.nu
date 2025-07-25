#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/04 13:06:56
# Usage:
#   t show-env

use ../utils/common.nu [get-tmp-path get-env get-ver]

# Show locally installed cli app's version and env information
export def main [] {
  let termixDir = (get-env TERMIX_DIR '(empty)')
  let shell = (get-env SHELL_TO_RUN_CMD '(empty)')
  let justFile = (get-env JUST_FILE_PATH '(empty)')
  let termixTmp = get-tmp-path
  let justInvokeDir = (get-env JUST_INVOKE_DIR '(empty)')
  let syncIgnore = (get-env SYNC_IGNORE_ALIAS '(empty)')
  let npmVer = (get-ver npm 'npm --version')
  let pnpmVer = (get-ver pnpm 'pnpm --version')
  let herdVer = (get-ver herd 'herd --version')
  let termixVer = (get-ver termix 'termix --version')
  let nodeVer = (get-ver node '(node --version | str substring 1..)')
  let fnmVer = (get-ver fnm "fnm --version | str trim | str substring 4..")
  let justVer = (get-ver just "just --version | str trim | str substring 5..")
  let gitVer = (get-ver git "git --version | str trim | str substring 12..")
  let s5cmdVer = (get-ver s5cmd 's5cmd version | split row - | first | str trim -c v')
  let time = (date now | format date '%Y/%m/%d %H:%M:%S')
  let gitProxy = if (git config --global --list | grep proxy | is-empty) { 'Off' } else { 'On' }

  print -n (char nl)
  version | select version commit_hash installed_plugins
    | upsert commit_hash { $in | str substring 0..7 }
    | transpose | rename Nu value | print

  char nl | print -n

  print [
    [name, value];
    ['Git', $gitVer]
    ['Fnm', $fnmVer]
    ['Just', $justVer]
    ['Node', $nodeVer]
    ['Npm', $npmVer]
    ['Pnpm', $pnpmVer]
    ['fzf', (get-ver fzf 'fzf --version')]
    ['s5cmd', $s5cmdVer]
    ['.OS.', (sys host | get long_os_version | str trim)]
    ['Herd', $herdVer]
    ['Termix', $termixVer]
    ['Package Tools', (get-ver package-tools 'package-tools --version')]
    ['------------', '-------------']
    ['Brew Managed', (get-brew-installed-bins | str join ', ')]
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

# Get brew managed tools that are required by termix-nu
def get-brew-installed-bins [] {
  [fzf s5cmd nushell just]
    | where {|bin| (brew list $bin | complete | get exit_code) == 0 }
    | default -e [N/A]
}
