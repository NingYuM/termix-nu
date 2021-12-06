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
  let nodeVer = (get-ver node '(node --version | str substring 1,)')
  let fnmVer = (get-ver fnm "(fnm --version | str find-replace 'fnm ' '' | first)")
  let justVer = (get-ver just "just --version | str find-replace 'just ' '' | first")
  let gitVer = (get-ver git "git --version | str find-replace 'git version' '' | str trim")
  let time = (date now | date format -t '%Y/%m/%d %H:%M:%S')

  # echo $env
  ^echo (nu -c 'version | pivot | rename nu-ver value')

  echo [
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
    ['SHELL_TO_RUN_CMD', $shell]
    ['SYNC_IGNORE_ALIAS', $syncIgnore]
    ['JUST_FILE', $justFile]
    ['TERMIX_TMP_PATH', $termixTmp]
    ['TERMIX_DIR', $termixDir]
    ['JUST_INVOKE_DIR', $justInvokeDir]
    ['Current Time', $time]
  ]
}
