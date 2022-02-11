# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it

# Global date format
let _DATE_FMT = '%Y.%m.%d'
let _TIME_FMT = '%Y-%m-%d %H:%M:%S'
let _UPGRADE_TAG = '$-FORCE-UPGRADE-$'

# Termix.toml config file path
let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)

# Current OS: windows / macos
let _OS = (version).build_os

# Get the specified env key's value or ''
def 'get-env' [
  key: string       # The key to get it's env value
  default?: string  # The default value for an empty env
] {
  let hasEnv = (env | any? name == $key)
  if $hasEnv { $env | get $key } else { $default }
}

# Get the specified config from `termix.toml` by key
def 'get-conf' [
  key: string       # The key to get it's value from termix.toml
  default?: any     # The default value for an empty conf
] {
  let result = (open $_TERMIX_CONF | get $key)
  if ($result | empty?) { $default } else { $result }
}

# Get TERMIX_TMP_PATH
def 'get-tmp-path' [] {
  let actionConf = (open $_TERMIX_CONF)
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  let tmpPath = (if ($tmpDir | empty?) { ($actionConf | get termixTmpPath) } else { $tmpDir })
  if ($tmpPath | path exists) == $false {
    $'(ansi r)Path ($tmpPath) does not exist, please create it and try agian...(ansi reset)(char nl)(char nl)'
    exit --now
  }
  echo $tmpPath
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
def 'get-ver' [
  app: string     # The CLI App to check
  verCmd: string  # The Nushell command to get it's version number
] {
  let installed = ((which $app | length) > 0)
  echo (if $installed { (nu -c $verCmd) } else { 'N/A' })
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
def 'has-ref' [
  ref: string   # The git ref to check
] {
  let parse = (git rev-parse --verify -q $ref)
  if ($parse | empty?) { $false } else { $true }
}

# Compare two version number, return true if first one is lower then second one
def 'is-lower-ver' [
  from: string,
  to: string,
] {
  let dest = ($to | str trim -c 'v' | str trim)
  let source = ($from | str trim -c 'v' | str trim)
  # 将三段式版本号转换成一个整数，每段最大值999，三段拼接一起进行比较
  let t = ($dest | split row '.' | each { $it | str lpad -l 3 -c '0' })
  let f = ($source | split row '.' | each { $it | str lpad -l 3 -c '0' })
  let toVer = ($t | str collect | into int)
  let fromVer = ($f | str collect | into int)
  if ($fromVer < $toVer) { echo $true } else { echo $false }
}

# Check if git was installed and if current directory is a git repo
def 'git-check' [
  dest: string        # The dest dir to check
  --check-repo: int   # Check if current directory is a git repo
] {
  cd $dest
  let isGitInstalled = ((which git | length) > 0)
  if $isGitInstalled == $false {
    $'You should (ansi r)INSTALL git(ansi reset) first to run this command, bye...'
    exit --now
  }
  # If we don't need repo check just quit now
  if ($check-repo == 0) {} else {

    do -i {
      let isGitRepo = (bash -c 'git rev-parse --is-inside-work-tree 2>/dev/null' | str trim)
      if ($isGitRepo == 'true') {} else {
        $'Current directory is (ansi r)NOT(ansi reset) a git repo, bye...(char nl)'
        exit --now
      }
    }
  }
}

# Log some variables
def 'log' [
  name: string
  var: any
] {
  $'(ansi g)-------------> Debug Begin: ($name) <---------------------(ansi reset)'
  echo $var
  $'(ansi g)------------->  Debug End <---------------------(char nl)(ansi reset)'
}
