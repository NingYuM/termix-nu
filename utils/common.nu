#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/10 07:36:56
# Usage:
#   use source command to load it
#   use std; scope commands | where type == 'custom' | where name =~ '^std ' | select name
#   use std-rfc; scope commands | where type == 'custom' | where name =~ '^std-rfc ' | select name

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

export const _DATE_FMT = '%Y.%m.%d'
export const _TIME_FMT = '%Y/%m/%d %H:%M:%S'
export const _UPGRADE_TAG = '$-FORCE-UPGRADE-$'

# Host pattern for http url
# HTTP/HTTPS host with optional port. Rules:
# - Scheme must be http or https
# - Host must be one of:
#   - a fully-qualified domain name with at least one dot and a valid TLD (letters, length ≥ 2)
#   - localhost
#   - an IPv4 address (0-255 per octet)
# - Optional port, 1-99999 (keep loose upper bound)
# Note: This intentionally rejects a single label like `https://a`
export const HOST_PATTERN = [
  '^(https?://)(?:'
  '(?:localhost)'
  '|(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}'
  '|(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)'
  ')(?::[1-9][0-9]{0,4})?$'
] | str join ''

# It takes longer to respond to requests made with unknown/rare user agents.
# When make http post pretend to be curl, it gets a response just as quickly as curl.
export const HTTP_HEADERS = [User-Agent curl/8.9]

export const FZF_KEY_BINDING = '--bind ctrl-b:preview-half-page-up,ctrl-f:preview-half-page-down,ctrl-/:toggle-preview'
export const FZF_DEFAULT_OPTS = $'--height 70% --layout=reverse --highlight-line --marker ▏ --pointer ▌ --prompt "▌ " --exact --preview-window=right:65%:~2 ($FZF_KEY_BINDING)'
export const FZF_THEME = '--color=gutter:-1,selected-bg:238,selected-fg:146,current-fg:189,bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#cf87f2,marker:#cf87f2,fg+:#ebdbb2,prompt:#86b3e7,hl+:#fb4934'

# Commonly used exit codes
export const ECODE = {
  SUCCESS: 0,
  OUTDATED: 1,
  AUTH_FAILED: 2,
  SERVER_ERROR: 3,
  MISSING_BINARY: 5,
  COMMAND_FAILED: 110,
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

  $ellie | str join "\n" | $"(ansi green)($in)(ansi rst)"
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

# If current host is Linux
# This is a workaround for the issue that `sys host` may return 'Ubuntu', etc.
export def linux? [] {
  $nu.os-info.name == 'linux' or (sys host | get name | str downcase) =~ 'linux'
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
  $env | get -o $key | default $default
  # let hasEnv = (env | any { |it| $it.name == $key })
  # if $hasEnv { $env | get $key } else { $default }
}

# Show a progress spinner while running a command
export def with-progress [
  message: string,         # Message to display
  action: closure,         # Action to perform
  --success: string,       # Success message
  --error: string          # Error message
] {
  print -n $'($message)   '
  # ASCII spinner frames
  let frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']

  # Start the spinner in the background
  let spinner_pid = job spawn {
    mut i = 0
    print -n (ansi cursor_off)
    loop {
      print -n (ansi cursor_left)
      print -n ($frames | get $i)
      sleep 100ms
      $i = ($i + 1) mod ($frames | length)
    }
  }

  # Run the action and capture result
  let result = try { do $action; { success: true } } catch { { success: false } }

  # Stop the spinner
  job kill $spinner_pid
  print "\r                                                  \r"

  if $result.success {
    print ($success | default '✓ Done!')
  } else {
    print ($error | default '✗ Failed!')
  }
}

# Simple progress bar
def simple-pv [update_interval: duration = 1sec]: any -> any {
  tee {
    each { date now }
    | enumerate
    | generate {|row, state={}|
      let current_count = $row.index
      let current_timestamp = $row.item

      if ($state == {}) {
        # Initialize state based on the first row
        return {
          next: {
            prev_count: $current_count
            first_timestamp: $current_timestamp
            prev_timestamp: $current_timestamp
            last_update_time: $current_timestamp
          }
        }
      }
      if (($current_timestamp - $state.last_update_time) >= $update_interval) {
        let count_delta = $current_count - $state.prev_count
        let timestamp_delta_sec = ($current_timestamp - $state.prev_timestamp) / 1sec
        let elapsed = ($current_timestamp - $state.first_timestamp) // 1sec * 1sec | into string | fill -w 10

        let speed = $count_delta / $timestamp_delta_sec | into string --decimals 2
        let time_per_item = $timestamp_delta_sec / $count_delta | into string --decimals 6

        print -n $"\r($current_count)  ($elapsed)  ($speed) item/sec  ($time_per_item) sec/item"

        return {
          next: {
            prev_count: $current_count
            first_timestamp: $state.first_timestamp
            prev_timestamp: $current_timestamp
            last_update_time: $current_timestamp
          }
        }
      }
      return {
        next: {
          prev_count: $current_count
          first_timestamp: $state.first_timestamp
          prev_timestamp: $current_timestamp
          last_update_time: $state.last_update_time
        }
      }
    }
  }
}

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

# Converts a .env file into a record
# May be used like this: open .env | load-env
# Works with quoted and unquoted .env files
export def "from env" []: string -> record {
  let input = $in

  # Process escape sequences in double-quoted values using regex with closure
  let process_escapes = {|content: string|
    $content | str replace -a -r '\\(.)' {|c|
      match $c {
        'n' => (char nl),
        'r' => (char cr),
        't' => (char tab),
        _ => $c
      }
    }
  }

  # Parse double-quoted value with escape sequence support
  let parse_double_quoted = {|val: string|
    let matched = ($val | parse -r '^"(?P<content>(?:[^"\\]|\\.)*)"')
    if ($matched | is-empty) { $val | str trim -c '"' } else { do $process_escapes $matched.0.content }
  }

  # Parse single-quoted value (no escape processing)
  let parse_single_quoted = {|val: string|
    let matched = ($val | parse -r "^'(?P<content>[^']*)'")
    if ($matched | is-empty) { $val | str trim -c "'" } else { $matched.0.content }
  }

  # Parse unquoted value: handle escaped hash (\#) and strip inline comments
  let parse_unquoted = {|val: string|
    $val
      | str replace -a '\#' (char nul)    # Placeholder for \#
      | split row '#'                     # Split by comment delimiter
      | first                             # Take content before first #
      | str replace -a (char nul) '#'     # Restore \# to #
      | str trim
  }

  # Parse value based on its format
  let parse_value = {|val: string|
    match $val {
      $v if ($v | str starts-with '"') => { do $parse_double_quoted $v }
      $v if ($v | str starts-with "'") => { do $parse_single_quoted $v }
      _ => { do $parse_unquoted $val }
    }
  }

  let parsed = $input | lines
    | str trim
    | compact -e
    | where {|line| not ($line | str starts-with '#') }
    | parse "{key}={value}"
    | update key {|row| $row.key | str trim | str replace -r '^export\s+' '' }
    | update value {|row| do $parse_value ($row.value | str trim) }

  if ($parsed | is-empty) { {} } else { $parsed | transpose -r -d -l }
}

# Get TERMIX_TMP_PATH from env first and fallback to HOME/.termix-nu
export def get-tmp-path [] {
  # let homeEnv = if (windows?) { 'USERPROFILE' } else { 'HOME' }
  let DEFAULT_TMP = [$nu.home-dir '.termix-nu'] | path join
  # 先从环境变量里面查找临时文件路径
  let tmpDir = (get-env TERMIX_TMP_PATH '')
  # 如果环境变量里面没有配置临时文件路径，则使用 HOME 目录下的 .termix 目录
  let tmpPath = if ($tmpDir | is-empty) {
    if not ($DEFAULT_TMP | path exists) { mkdir $DEFAULT_TMP }
    $DEFAULT_TMP
  } else { $tmpDir }
  if not ($tmpPath | path exists) {
    print $'(ansi r)Path ($tmpPath) does not exist, please create it and try again...(ansi rst)(char nl)(char nl)'
    exit $ECODE.MISSING_DEPENDENCY
  }
  # print $'Using (ansi g)($tmpPath)(ansi rst) as the temporary directory...(char nl)'
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
  let checkRepo = git rev-parse --is-inside-work-tree | complete
  if not ($checkRepo.stdout =~ 'true') { return false }
  let parse = do { ^git rev-parse --verify -q $ref | complete }
  ($parse.stdout | is-not-empty)
}

# A custom command to check if a string is a valid SemVer version
export def is-semver [version?: string] {
  let version = if ($version | is-empty) { $in } else { $version }
  if ($version | is-empty) { return false }
  # Use regex pattern to match the SemVer version string
  # The `v` prefix is optional.
  let semver_pattern = '^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
  # Check if the version string matches the SemVer pattern
  $version =~ $semver_pattern
}

# Parse a SemVer version string into its components
# Usage:
#   parse-semver v1.2.3-beta+build
#   parse-semver 2.5.8-rc.1+exp.sha.511c985
export def parse-semver [version: string] {
  if not ($version | is-semver) {
    error make {
      msg: 'Invalid SemVer format',
      label: {
        text: $'It is not a SemVer: ($version)',
        span: (metadata $version).span
      }
    }
  }

  let cleaned = $version | str replace -r '^v' ''

  # Split by + to separate build metadata
  let build_parts = $cleaned | split row '+'
  let version_part = $build_parts.0
  let build = $build_parts.1? | default ''

  # Split by - to separate pre-release
  let pre_parts = $version_part | split row '-'
  let core_version = $pre_parts.0
  let pre = if ($pre_parts | length) > 1 { $pre_parts | skip 1 | str join '-' } else { '' }

  # Parse core version numbers
  let core = $core_version | split row '.' | each { into int }
  { major: $core.0, minor: $core.1, patch: $core.2, pre: $pre, build: $build }
}

# Compare two version numbers according to SemVer rules
# Returns: 1 (v1 > v2), 0 (v1 = v2), -1 (v1 < v2)
export def compare-ver [v1: string, v2: string] {
  # Parse version string into structured data, adding pre-release flag.
  def parse [version: string] {
    let parsed = parse-semver $version
    { ...$parsed, is_prerelease: ($parsed.pre | is-not-empty) }
  }

  # Compare two pre-release version parts
  def compare-prerelease-part [p1: string, p2: string] {
    # Try numeric comparison first
    let n1 = try { $p1 | into int } catch { null }
    let n2 = try { $p2 | into int } catch { null }

    match [$n1, $n2] {
      # Both text
      [null, null] => { if $p1 > $p2 { 1 } else if $p1 < $p2 { (-1) } else { 0 } },
      # Numeric < text
      [$n1, null]  => { (-1) },
      # Text > numeric
      [null, $n2]  => { 1 },
      # Both numeric
      [$n1, $n2]   => { if $n1 > $n2 { 1 } else if $n1 < $n2 { (-1) } else { 0 } }
    }
  }

    # Compare pre-release versions
  def compare-prerelease [pre1: string, pre2: string, is_pre1: bool, is_pre2: bool] {
    # Release > pre-release
    if (not $is_pre1) and $is_pre2 { return 1 }
    if $is_pre1 and (not $is_pre2) { return (-1) }
    if (not $is_pre1) and (not $is_pre2) { return 0 }

    # Both are pre-release, compare their parts.
    let parts1 = $pre1 | split row '.'
    let parts2 = $pre2 | split row '.'
    let max_len = [($parts1 | length), ($parts2 | length)] | math max

    for i in 0..<$max_len {
      let p1 = $parts1 | get -o $i
      let p2 = $parts2 | get -o $i

      # Shorter version < longer version (e.g., 1.0.0-alpha < 1.0.0-alpha.1)
      if ($p1 == null) { return (-1) }
      if ($p2 == null) { return 1 }

      let result = compare-prerelease-part $p1 $p2
      if $result != 0 { return $result }
    }
    0
  }

  let ver1 = parse $v1
  let ver2 = parse $v2

  # Compare core version numbers
  for field in ['major', 'minor', 'patch'] {
    let a = $ver1 | get $field
    let b = $ver2 | get $field
    if $a > $b { return 1 }
    if $a < $b { return (-1) }
  }

  # Compare pre-release (build metadata ignored per SemVer spec)
  compare-prerelease $ver1.pre $ver2.pre $ver1.is_prerelease $ver2.is_prerelease
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
    print $'You should (ansi r)INSTALL git(ansi rst) first to run this command, bye...'
    exit $ECODE.MISSING_BINARY
  }
  # If we don't need repo check just quit now
  if ($check_repo != 0) {
    let checkRepo = (do -i { git rev-parse --is-inside-work-tree } | complete)
    if not ($checkRepo.stdout =~ 'true') {
      print $'Current directory is (ansi r)NOT(ansi rst) a git repo, bye...(char nl)'
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
  print $'(ansi g)(build-line 18)> Debug Begin: ($name) <(build-line 18)(ansi rst)'
  print $var
  print $'(ansi g)(build-line 20)>  Debug End <(build-line 20)(char nl)(ansi rst)'
}

export def hr-line [
  width?: int = 90,
  --blank-line(-b),
  --with-arrow(-a),
  --color(-c): string = 'g',
] {
  print $'(ansi $color)(build-line $width)(if $with_arrow {'>'})(ansi rst)'
  if $blank_line { print -n (char nl) }
}

# 渲染 ANSI 颜色代码
export def render-ansi [text: string] {
  # Map of color codes: short name -> actual ansi code
  const ANSI_MAP = {
    g: 'g', r: 'r', y: 'y', cb: 'cb', p: 'p',
    gr: 'grey66', rst: 'reset', reset: 'reset'
  }
  $text | str replace -a -r '\(ansi ([a-z]+)\)' {|code|
    ansi ($ANSI_MAP | get -o $code | default $code)
  }
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
  if not ($TERMIX_CONF | path exists) { return $default }
  open $TERMIX_CONF | from json | get -o $key | default $default
}

# Set the value of key to ~/.termix-nu/.termix-conf
export def set-dot-conf [key: string, value: any] {
  let TERMIX_CONF = $'(get-tmp-path)/.termix-conf'
  let conf = if ($TERMIX_CONF | path exists) { open $TERMIX_CONF | from json } else { {} }
  $conf
    | upsert $key $value | to json
    | save -rf $TERMIX_CONF
}

# Get the empty keys from a record, return null if all keys are set
export def get-empty-keys [record: any, keys: list<string>] {
  let empties = $keys | where {|ky| $record | get -o $ky | is-empty }
  if ($empties | length) > 0 { $empties } else { null }
}
