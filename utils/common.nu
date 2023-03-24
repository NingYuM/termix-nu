#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it

# Global date format
# let _DATE_FMT = '%Y.%m.%d'
# let _TIME_FMT = '%Y-%m-%d %H:%M:%S'
# let _UPGRADE_TAG = '$-FORCE-UPGRADE-$'

# FIXME
export def _DATE_FMT [] { '%Y.%m.%d' }
export def _TIME_FMT [] { '%Y-%m-%d %H:%M:%S' }
export def _UPGRADE_TAG [] { '$-FORCE-UPGRADE-$' }
export def _TERMIX_CONF [] { ([$env.TERMIX_DIR 'termix.toml'] | path join) }

# Termix.toml config file path
# let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)

# If current host is Windows
export def windows? [] {
  # Windows / Darwin
  (sys).host.name == 'Windows'
}

# Get the specified env key's value or ''
export def 'get-env' [
  key: string       # The key to get it's env value
  default?: string  # The default value for an empty env
] {
  $env | get -i $key | default $default
  # let hasEnv = (env | any { |it| $it.name == $key })
  # if $hasEnv { $env | get $key } else { $default }
}

# Get the specified config from `termix.toml` by key
export def 'get-conf' [
  key: string       # The key to get it's value from termix.toml
  default?: any     # The default value for an empty conf
] {
  # FIXME
  let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)
  let result = (open $_TERMIX_CONF | get $key)
  if ($result | is-empty) { $default } else { $result }
}

# Get TERMIX_TMP_PATH
export def 'get-tmp-path' [] {
  # FIXME
  let _TERMIX_CONF = ([$env.TERMIX_DIR 'termix.toml'] | path join)
  let actionConf = (open $_TERMIX_CONF)
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  let tmpPath = if ($tmpDir | is-empty) { ($actionConf | get termixTmpPath) } else { $tmpDir }
  if ($tmpPath | path exists) == false {
    print $'(ansi r)Path ($tmpPath) does not exist, please create it and try again...(ansi reset)(char nl)(char nl)'
    exit --now
  }
  echo $tmpPath
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
export def 'get-ver' [
  app: string     # The CLI App to check
  verCmd: string  # The Nushell command to get it's version number
] {
  let installed = (which $app | length) > 0
  echo (if $installed { (nu -c $verCmd | str trim) } else { 'N/A' })
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
export def 'has-ref' [
  ref: string   # The git ref to check
] {
  # Brackets were required here, or error will occur
  let parse = (do -i { (git rev-parse --verify -q $ref) })
  if ($parse | is-empty) { false } else { true }
}

# Compare two version number, return true if first one is lower then second one
export def 'is-lower-ver' [
  from: string,
  to: string,
] {
  let dest = ($to | str trim -c 'v' | str trim)
  let source = ($from | str trim -c 'v' | str trim)
  # 将三段式版本号转换成一个整数，每段最大值999，三段拼接一起进行比较
  let t = ($dest | split row '.' | each { |it| $it | fill -a r -w 3 -c '0' })
  let f = ($source | split row '.' | each { |it| $it | fill -a r -w 3 -c '0' })
  let toVer = ($t | str join | into int)
  let fromVer = ($f | str join | into int)
  ($fromVer < $toVer)
}

# Check if git was installed and if current directory is a git repo
export def 'git-check' [
  dest: string        # The dest dir to check
  --check-repo: int   # Check if current directory is a git repo
] {
  cd $dest
  let isGitInstalled = (which git | length) > 0
  if (not $isGitInstalled) {
    print $'You should (ansi r)INSTALL git(ansi reset) first to run this command, bye...'
    exit --now
  }
  # If we don't need repo check just quit now
  if ($check_repo != 0) {
    let checkRepo = (do -i { git rev-parse --is-inside-work-tree } | complete)
    if not ($checkRepo.stdout =~ 'true') {
      print $'Current directory is (ansi r)NOT(ansi reset) a git repo, bye...(char nl)'
      exit --now
    }
  }
}

# Log some variables
export def 'log' [
  name: string
  var: any
] {
  print $'(ansi g)-----------------> Debug Begin: ($name) <-----------------(ansi reset)'
  print $var
  print $'(ansi g)------------------->  Debug End <---------------------(char nl)(ansi reset)'
}

export def 'hr-line' [
  --blank-line(-b): bool
] {
  print $'(ansi g)---------------------------------------------------------------------------->(ansi reset)'
  if $blank_line { char nl }
}

export def ! [b: expr] { if ($b) { false } else { true } }
