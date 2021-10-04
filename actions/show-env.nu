# Author: hustcer
# Created: 2021/10/04 13:06:56
# Usage:
#   t show-env

# Show locally installed cli app's version and env infomation
def 'show-env' [] {
  let npmVer = (npm --version)
  let yarnVer = (yarn --version)
  let termixVer = (termix --version)
  let env = ($nu.env | pivot key value)
  let nodeVer = (node --version | str substring '1,')
  let justVer = (just --version | str find-replace 'just ' '' | first)
  let gitVer = (git --version | str find-replace 'git version' '' | str trim)
  let time = (date now | date format -t '%Y/%m/%d %H:%M:%S')
  let termixDir = ($env | match key TERMIX_DIR | get value)
  let shell = ($env | match key SHELL_TO_RUN_CMD | get value)
  let redevPath = ($env | match key REDEV_REPO_PATH | get value)
  let justInvokeDir = ($env | match key JUST_INVOKE_DIR | get value)
  let justFile = ($env | match key JUST_FILE_PATH | get value)

  # echo $env
  echo (nu -c 'version | pivot | rename nu-ver value')
  echo [
      [name, value];
      ['Git', $gitVer]
      ['Just', $justVer]
      ['Node', $nodeVer]
      ['Npm', $npmVer]
      ['Yarn', $yarnVer]
      ['Termix', $termixVer]
      ['SHELL_TO_RUN_CMD', $shell]
      ['JUST_FILE', $justFile]
      ['REDEV_REPO_PATH', $redevPath]
      ['TERMIX_DIR', $termixDir]
      ['JUST_INVOKE_DIR', $justInvokeDir]
      ['Time', $time]
    ]
}

show-env
