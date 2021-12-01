# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it

let __env = ($nu.env | pivot key value)

# Termix.toml config file path
let _TERMIX_CONF = ([$nu.env.TERMIX_DIR 'termix.toml'] | path join)

# Current OS: windows / macos
let _OS = (version | pivot name value | match name build_os | get value)

# Get the specified env key's value or ''
def 'get-env' [
  key: string     # The key to get it's env value
  default?: string # The default value for an empty env
] {
  let val = ($__env | match key $key | get value)
  if ($val | empty?) { $default } { $val }
}

# Get the specified config from `termix.toml` by key
def 'get-conf' [
  key: string       # The key to get it's value from termix.toml
  default?: any     # The default value for an empty conf
] {
  let result = (open $_TERMIX_CONF | get ($key | into column_path))
  if ($result | empty?) { $default } { $result }
}

# Get TERMIX_TMP_PATH
def 'get-tmp-path' [] {
  let actionConf = (open $_TERMIX_CONF)
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  let tmpPath = (if ($tmpDir | empty?) { ($actionConf | get termixTmpPath) } { $tmpDir })
  echo $tmpPath
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
def 'get-ver' [
  app: string     # The CLI App to check
  verCmd: string  # The Nushell command to get it's version number
] {
  let installed = ((which $app | length) > 0)
  echo (if $installed { nu -c $verCmd }  { 'N/A' })
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
def 'has-ref' [
  ref: string   # The git ref to check
] {
  let parse = (git rev-parse --verify -q $ref)
  if ($parse | empty?) { $false } { $true }
}

# Compare two version number, return true if first one is lower then second one
def 'is-lower-ver' [
  from: string,
  to: string,
] {
  let dest = ($to | str trim -c 'v' | str trim)
  let source = ($from | str trim -c 'v' | str trim)
  let t = ($dest | split row '.' | each { $it | into int })
  let f = ($source | split row '.' | each { $it | into int })
  if (($f.0 < $t.0) || ($f.1 < $t.1) || ($f.2 < $t.2)) { echo $true } { echo $false }
}

# Check if git was installed and if current directory is a git repo
def 'git-check' [
  dest: string        # The dest dir to check
  --check-repo: int   # Check if current directory is a git repo
] {
  cd $dest
  let isGitInstalled = ((which git | length) > 0)
  if $isGitInstalled {} {
    $'You should (ansi r)INSTALL git(ansi reset) first to run this command, bye...'
    exit --now
  }
  # If we don't need repo check just quit now
  if ($check-repo == 0) {} {

    do -i {
      let isGitRepo = (bash -c 'git rev-parse --is-inside-work-tree 2>/dev/null' | str trim)
      if ($isGitRepo == 'true') {} {
        $'Current directory is (ansi r)NOT(ansi reset) a git repo, bye...(char nl)'
        exit --now
      }
    }
  }
}
