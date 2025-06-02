#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it

# Global date format
# let _DATE_FMT = '%Y.%m.%d'
# let _TIME_FMT = '%Y-%m-%d %H:%M:%S'
# let _UPGRADE_TAG = '$-FORCE-UPGRADE-$'

# All available exit codes:
#   0: Success
#   1: Outdated
#   2: Auth failed
#   3: Server error
#   5: Missing binary
#   6: Invalid parameter
#   7: Missing dependency
#   8: Condition not satisfied

export const _DATE_FMT  = '%Y.%m.%d'
export const _TIME_FMT =  '%Y/%m/%d %H:%M:%S'
export const _UPGRADE_TAG = '$-FORCE-UPGRADE-$'

# It takes longer to respond to requests made with unknown/rare user agents.
# When make http post pretend to be curl, it gets a response just as quickly as curl.
export const HTTP_HEADERS = [User-Agent curl/8.9]

export const FZF_KEY_BINDING = '--bind ctrl-b:preview-half-page-up,ctrl-f:preview-half-page-down,ctrl-/:toggle-preview'
export const FZF_DEFAULT_OPTS = $'--height 50% --layout=reverse --highlight-line --marker ▏ --pointer ▌ --prompt "▌ " --exact --preview-window=right:65%:~2 ($FZF_KEY_BINDING)'
export const FZF_THEME = '--color=gutter:-1,selected-bg:238,selected-fg:146,current-fg:189,bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#cf87f2,marker:#cf87f2,fg+:#ebdbb2,prompt:#86b3e7,hl+:#fb4934'

# Commonly used exit codes
export const ECODE = {
  SUCCESS: 0,
  OUTDATED: 1,
  AUTH_FAILED: 2,
  SERVER_ERROR: 3,
  MISSING_BINARY: 5,
  INVALID_PARAMETER: 6,
  MISSING_DEPENDENCY: 7,
  CONDITION_NOT_SATISFIED: 8,
}

export-env {
  # FIXME: 去除前导空格背景色
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
}

# the cute and friendly mascot of Nushell :)
export def ellie [] {
  let ellie = [
    "     __  ,",
    " .--()°'.'",
    "'|, . ,'",
    " !_-(_\\",
  ]

  $ellie | str join "\n" | $"(ansi green)($in)(ansi reset)"
}

# Termix.toml config file path
export def get-termix-conf [] { ([$env.TERMIX_DIR 'termix.toml'] | path join) }

# If current host is Windows
export def windows? [] {
  # Windows / Darwin
  (sys host | get name) == 'Windows'
}

# If current host is macOS
export def mac? [] {
  # Windows / Darwin
  (sys host | get name) == 'Darwin'
}

# Compact the record by removing empty columns
export def compact-record []: record -> record {
  let record = $in
  let empties = $record | columns | where {|it| $record | get $it | is-empty }
  $record | reject ...$empties
}

# Calculate the base32 hash of a string or file like pnpm's patch hash implementation
# The hash result should be consistent across different platforms
export def base32-hash [file?: string] {
  mut input = $in
  if ($file | is-not-empty) {
    $input = open $file --raw | decode utf-8
  }
  $input
    | str replace -a "\r\n" "\n"
    | hash md5 --binary
    | encode base32 --nopad
    | str downcase
}

# Check if some command available in current shell
export def is-installed [ app: string ] {
  (which $app | length) > 0
}

# Get the specified env key's value or ''
export def get-env [
  key: string,       # The key to get it's env value
  default?: string,  # The default value for an empty env
] {
  $env | get -i $key | default $default
  # let hasEnv = (env | any { |it| $it.name == $key })
  # if $hasEnv { $env | get $key } else { $default }
}

# Show a progress spinner while running a command
# def with-progress [
#   message: string,         # Message to display
#   action: closure,         # Action to perform
#   --success: string,       # Success message
#   --error: string          # Error message
# ] {
#   print -n $'($message)   '
#   # ASCII spinner frames
#   let frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']

#   # Start the spinner in the background
#   let spinner_pid = job spawn {
#     mut i = 0
#     print -n (ansi cursor_off)
#     loop {
#       print -n (ansi cursor_left)
#       print -n ($frames | get $i)
#       sleep 100ms
#       $i = ($i + 1) mod ($frames | length)
#     }
#   }

#   # Run the action and capture result
#   let result = try { do $action; { success: true } } catch { { success: false } }

#   # Stop the spinner
#   job kill $spinner_pid
#   print "\r                                                  \r"

#   if $result.success {
#     print ($success | default '✓ Done!')
#   } else {
#     print ($error | default '✗ Failed!')
#   }
# }

# Get the specified config from `termix.toml` by key
export def get-conf [
  key: string,       # The key to get it's value from termix.toml
  default?: any,     # The default value for an empty conf
] {
  let _TERMIX_CONF = get-termix-conf
  let result = (open $_TERMIX_CONF | get $key)
  if ($result | is-empty) { $default } else { $result }
}

def --env defer [fn: closure] { $env.deferred ++= [$fn] }

# with-defer {
#   defer { print "fourth"}
#   print "first!"
#   defer { print "third"}
#   print "second!"
# }
def with-defer [fn: closure] {
  $env.deferred = []
  let r = try { do --env $fn | { ok: $in } } catch {|e| { err: $e } }
  for d in ($env.deferred | reverse) {
    try { do --env $d }
  }
  $env.deferred = []
  match $r {
    { ok: $ok } => $ok,
    { err: $err } => $err.raw,
  }
}

def children [val: any, path: cell-path]: [nothing -> table<path: cell-path, item: any>] {
  match ($val | describe -d).type {
    'record' => { $val | transpose path item }
    'list' => { $val | enumerate | rename path item }
    _ => { return [] }
  }
  | update path {|row|
    $path | split cell-path | append {value: $row.path} | into cell-path
  }
}

# Streaming traverse
export def traverse []: [any -> list<any>] {
  ignore
  generate {|out|
      let children = $out | each {|e| children $e.item $e.path } | flatten | compact -e
      if ($children | is-not-empty) {
        {out: $out, next: $children}
      } else {
        {out: $out}
      }
    } [{ path: ($.), item: ($in) }]
  | flatten
}

export def 'from sse' [] {
  lines | generate {|line pending = {data: []}|
    match ($line | split row -n 2 ':' | each { str trim }) {
      [$prefix $content] if $prefix == 'id' => {
        return {next: ($pending | upsert id $content)}
      }

      [$prefix $content] if $prefix == 'event' => {
        return {next: ($pending | upsert event $content)}
      }

      [$prefix $content] if $prefix == 'data' => {
        return {next: ($pending | update data { append $content })}
      }

      [$empty] if $empty == '' => {
        if ($pending == {data: []}) {
          return {next: $pending}
        }
        return {next: {data: []} out: ($pending | update data { str join "\n" })}
      }

      _ => { error make {msg: $'unexpected: ($line)'} }
    }
  }
}

# Get TERMIX_TMP_PATH from env first and fallback to HOME/.termix-nu
export def get-tmp-path [] {
  # let homeEnv = if (windows?) { 'USERPROFILE' } else { 'HOME' }
  let DEFAULT_TMP = [$nu.home-path '.termix-nu'] | path join
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  # 如果环境变量里面没有配置临时文件路径，则使用 HOME 目录下的 .termix 目录
  let tmpPath = if ($tmpDir | is-empty) {
    if not ($DEFAULT_TMP | path exists) { mkdir $DEFAULT_TMP }
    $DEFAULT_TMP
  } else { $tmpDir }
  if not ($tmpPath | path exists) {
    print $'(ansi r)Path ($tmpPath) does not exist, please create it and try again...(ansi reset)(char nl)(char nl)'
    exit $ECODE.MISSING_DEPENDENCY
  }
  # print $'Using (ansi g)($tmpPath)(ansi reset) as the temporary directory...(char nl)'
  $tmpPath
}

# Check if a CLI App was installed, if true get the installed version, otherwise return 'N/A'
export def get-ver [
  app: string,     # The CLI App to check
  verCmd: string,  # The Nushell command to get it's version number
] {
  let installed = (which $app | length) > 0
  (if $installed { (nu -n --no-std-lib -c $verCmd | str trim) } else { 'N/A' })
}

# Check if a git repo has the specified ref: could be a branch or tag, etc.
export def has-ref [
  ref: string   # The git ref to check
] {
  let checkRepo = (do -i { git rev-parse --is-inside-work-tree } | complete)
  if not ($checkRepo.stdout =~ 'true') { return false }
  # Brackets were required here, or error will occur
  let parse = (do -i { git rev-parse --verify -q $ref } | complete)
  if ($parse.stdout | is-empty) { false } else { true }
}

# A custom command to check if a string is a valid SemVer version
def is-semver [version?: string] {
  let version = if ($version | is-empty) { $in } else { $version }
  if ($version | is-empty) { return false }
  # Use regex pattern to match the SemVer version string
  # The `v` prefix is not supported, add `v?` at the beginning of the regex if needed
  # ^v?(0|[1-9]\d*)\.(0|[1-9]\d*)... Keep the reset of the pattern the same
  let semver_pattern = '^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
  # Check if the version string matches the SemVer pattern
  if $version =~ $semver_pattern { true } else { false }
  # $version | str replace --regex $semver_pattern 'match' | $in == 'match'
}

# Parse a SemVer version string into its components
# Usage:
#   parse-semver v1.2.3-beta+build
#   parse-semver 2.5.8-rc.1+exp.sha.511c985
def parse-semver [version: string] {
  if not ($version | is-semver) {
    error make {
      msg: 'Invalid SemVer format',
      label: {
        text: 'It is not a SemVer',
        span: (metadata $version).span
      }
    }
  }

  let cleaned = $version | str replace -r '^v' '' | split row - | split row +
  let core = $cleaned.0 | split row . | each { into int }
  let pre = $cleaned.1? | default ''
  let build = $cleaned.2? | default ''
  { major: $core.0, minor: $core.1, patch: $core.2, pre: $pre, build: $build }
}

# Compare two version number, return `1` if first one is higher than second one,
# Return `0` if they are equal, otherwise return `-1`
# Examples:
#   compare-ver 1.2.3 1.2.0    # Returns 1
#   compare-ver 2.0.0 2.0.0    # Returns 0
#   compare-ver 1.9.9 2.0.0    # Returns -1
# Format: Expects semantic version strings (major.minor.patch)
#   - Optional 'v' prefix
#   - Pre-release suffixes (-beta, -rc, etc.) are ignored
#   - Missing segments default to 0
export def compare-ver [v1: string, v2: string] {
  # Parse the version number: remove pre-release and build information,
  # only take the main version part, and convert it to a list of numbers
  def parse-ver [v: string] {
    $v | str replace -r '^v' '' | str trim | split row -
       | first | split row . | each { into int }
  }
  let a = parse-ver $v1
  let b = parse-ver $v2
  # Compare the major, minor, and patch parts; fill in the missing parts with 0
  # If you want to compare more parts use the following code:
  # for i in 0..([2 ($a | length) ($b | length)] | math max)
  for i in 0..2 {
    let x = $a | get -i $i | default 0
    let y = $b | get -i $i | default 0
    if $x > $y { return 1    }
    if $x < $y { return (-1) }
  }
  0
}

# Compare two version number, return true if first one is lower then second one
export def is-lower-ver [
  from: string,
  to: string,
] {
  (compare-ver $from $to) < 0
}

# Check if git was installed and if current directory is a git repo
export def git-check [
  dest: string,        # The dest dir to check
  --check-repo: int,   # Check if current directory is a git repo
] {
  cd $dest
  let isGitInstalled = (which git | length) > 0
  if (not $isGitInstalled) {
    print $'You should (ansi r)INSTALL git(ansi reset) first to run this command, bye...'
    exit $ECODE.MISSING_BINARY
  }
  # If we don't need repo check just quit now
  if ($check_repo != 0) {
    let checkRepo = (do -i { git rev-parse --is-inside-work-tree } | complete)
    if not ($checkRepo.stdout =~ 'true') {
      print $'Current directory is (ansi r)NOT(ansi reset) a git repo, bye...(char nl)'
      exit $ECODE.CONDITION_NOT_SATISFIED
    }
  }
  true
}

# Create a line by repeating the unit with specified times
def build-line [
  times: int,
  unit: string = '-',
] {
  0..<$times | reduce -f '' { |i, acc| $unit + $acc }
}

# Log some variables
export def log [
  name: string,
  var: any,
] {
  print $'(ansi g)(build-line 18)> Debug Begin: ($name) <(build-line 18)(ansi reset)'
  print $var
  print $'(ansi g)(build-line 20)>  Debug End <(build-line 20)(char nl)(ansi reset)'
}

export def hr-line [
  width?: int = 90,
  --blank-line(-b),
  --with-arrow(-a),
  --color(-c): string = 'g',
] {
  print $'(ansi $color)(build-line $width)(if $with_arrow {'>'})(ansi reset)'
  if $blank_line { print -n (char nl) }
}

# Check if a path can be written
export def can-write [path: string] {
  try {
    $'($path)/check_write_perm' | tee { touch $in } | rm $in
    true
  } catch {
    false
  }
}

# parallel { print "Oh" } { print "Ah" } { print "Eeh" }
export def parallel [...closures] {
  $closures | par-each {
    |c| do $c
  }
}

# Display a progress bar with specified length
export def progress [
  count: int,               # Total tick count of the progress bar
  interval: float = 1.0,    # The interval between each tick
  --char(-c): string = '█', # The char to display for each tick
] {
  mut x = 0
  let duration = $'($interval)sec' | into duration
  # Available chars: █ ▓ ▒ ░ = - ~ *
  while $x < $count { print -n $char; $x = $x + 1; sleep $duration }
}

# Get the value of key from ~/.termix-nu/.termix-conf
export def get-dot-conf [key: string, default?: any] {
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  open $TERMIX_CONF | from json | get -i $key | default $default
}

# Set the value of key to ~/.termix-nu/.termix-conf
export def set-dot-conf [key: string, value: any] {
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let conf = if ($TERMIX_CONF | path exists) { open $TERMIX_CONF | from json } else { {} }
  $conf
    | upsert $key $value | to json
    | save -rf $TERMIX_CONF
}
