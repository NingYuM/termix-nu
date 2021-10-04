# Author: hustcer
# Created: 2021/10/04 13:06:56
# Usage:
#   t show-env

# Show locally installed cli app's version and env infomation
def 'show-env' [] {
  let termixDir = (get-env TERMIX_DIR)
  let shell = (get-env SHELL_TO_RUN_CMD)
  let justFile = (get-env JUST_FILE_PATH)
  let redevPath = (get-env REDEV_REPO_PATH)
  let justInvokeDir = (get-env JUST_INVOKE_DIR)
  let npmVer = (get-ver npm 'npm --version')
  let yarnVer = (get-ver yarn 'yarn --version')
  let termixVer = (get-ver termix 'termix --version')
  let nodeVer = (get-ver node '(node --version | str substring "1,")')
  let justVer = (get-ver just "just --version | str find-replace 'just ' '' | first")
  let gitVer = (get-ver git "git --version | str find-replace 'git version' '' | str trim")
  let time = (date now | date format -t '%Y/%m/%d %H:%M:%S')

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

let env = ($nu.env | pivot key value)

# Get the specified env key's value or ''
def 'get-env' [
  key: string   # The key to get it's env value
] {
  let val = ($env | match key $key | get value)
  if ($val | empty?) { '(empty)' } { $val }
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
def 'get-ver' [
  app: string     # The CLI App to check
  verCmd: string  # The Nushell command to get it's version number
] {
  let installed = ((which $app | length) > 0)
  echo (if $installed { nu -c $verCmd }  { 'N/A' })
}

show-env
