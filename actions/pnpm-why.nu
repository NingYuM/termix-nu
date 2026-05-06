#!/usr/bin/env nu

# Lockfile-first pnpm why helper.
# Usage:
#   nu pnpm-why.nu dayjs
#   nu pnpm-why.nu @alife/hooks
#   nu pnpm-why.nu got@13 --json
#
# Unlike `pnpm why`, this script reads `pnpm-lock.yaml` directly and reports
# which workspace importers already reference a dependency and which exact
# lockfile versions are available for reuse.

use ../utils/common.nu [compare-ver parse-semver]

def err [msg: string] { print -e $'(ansi r)($msg)(ansi rst)' }
def info [msg: string] { print $'(ansi c)($msg)(ansi rst)' }
def success [msg: string] { print $'(ansi g)($msg)(ansi rst)' }

const DEP_FIELDS = ['dependencies' 'optionalDependencies' 'devDependencies']

export def parse-package-spec [spec: string]: nothing -> record<name: string, version: string> {
  let trimmed = $spec | str trim
  if ($trimmed | is-empty) {
    return { name: '', version: '' }
  }

  let parsed = if ($trimmed starts-with '@') {
    let scoped_parts = $trimmed | split row '/'
    if ($scoped_parts | length) != 2 {
      { name: '', version: '' }
    } else {
      let scope = $scoped_parts.0
      let tail_parts = $scoped_parts.1 | split row '@'
      match ($tail_parts | length) {
        1 => { name: $'($scope)/($tail_parts.0)', version: '' }
        2 => { name: $'($scope)/($tail_parts.0)', version: $tail_parts.1 }
        _ => { name: '', version: '' }
      }
    }
  } else {
    let parts = $trimmed | split row '@'
    match ($parts | length) {
      1 => { name: $parts.0, version: '' }
      2 => { name: $parts.0, version: $parts.1 }
      _ => { name: '', version: '' }
    }
  }

  if not (is-ordinary-npm-spec $parsed.name $parsed.version) {
    return { name: '', version: '' }
  }

  $parsed
}

export def ordinary-npm-spec-error-message []: nothing -> string {
  'Only ordinary npm package specs are supported: name, name@version/range, @scope/name, or @scope/name@version/range. Alias/protocol/git/url specs are not supported.'
}

def is-ordinary-npm-spec [
  dep_name: string,
  version: string
]: nothing -> bool {
  if ($dep_name | is-empty) {
    return false
  }

  let name_ok = if ($dep_name starts-with '@') {
    $dep_name =~ '^@[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$'
  } else {
    $dep_name =~ '^[A-Za-z0-9._-]+$'
  }
  if not $name_ok {
    return false
  }

  if ($version | is-empty) {
    return true
  }

  if ($version | str contains ':') or ($version | str contains '/') {
    return false
  }

  $version =~ '^[A-Za-z0-9~^<>=.*xX| -]+$'
}

def version-token-parts [token: string]: nothing -> record<major: string, minor: string, patch: string> {
  let clean = $token | str trim | str trim --char '=' | str trim --char 'v' | split row '-' | first
  let parts = $clean | split row '.'
  {
    major: ($parts | get -o 0 | default 'x')
    minor: ($parts | get -o 1 | default 'x')
    patch: ($parts | get -o 2 | default 'x')
  }
}

def wildcard-part [value: string]: nothing -> bool {
  let lower = $value | str downcase
  ($lower == '') or ($lower == 'x') or ($lower == '*')
}

def version-part-to-int [value: string]: nothing -> int {
  if (wildcard-part $value) {
    return 0
  }

  try { $value | into int } catch { 0 }
}

def semver-string [
  major: int,
  minor: int,
  patch: int
]: nothing -> string {
  $'($major).($minor).($patch)'
}

def token-to-minimum [token: string]: nothing -> record<major: int, minor: int, patch: int, version: string> {
  let parts = version-token-parts $token
  let major = version-part-to-int $parts.major
  let minor = version-part-to-int $parts.minor
  let patch = version-part-to-int $parts.patch
  {
    major: $major
    minor: $minor
    patch: $patch
    version: (semver-string $major $minor $patch)
  }
}

def normalize-comparable-version [version: string]: nothing -> string {
  let clean = strip-lock-version-suffix $version | str trim
  if ($clean =~ '^v?[0-9]+\.[0-9]+\.[0-9]+($|[-+])') {
    return $clean
  }

  (token-to-minimum $clean).version
}

def compare-version [left: string, right: string]: nothing -> int {
  compare-ver (normalize-comparable-version $left) (normalize-comparable-version $right)
}

def version-gte [version: string, minimum: string]: nothing -> bool {
  (compare-version $version $minimum) >= 0
}

def version-lt [version: string, maximum: string]: nothing -> bool {
  (compare-version $version $maximum) < 0
}

def token-satisfies-version [
  base_version: string,
  range_token: string
]: nothing -> bool {
  let token = $range_token | str trim
  if ($token | is-empty) or ($token == '*') or (($token | str downcase) == 'x') {
    return true
  }

  if ($token starts-with '>=') {
    return (version-gte $base_version (token-to-minimum ($token | str substring 2..)).version)
  }
  if ($token starts-with '>') {
    return ((compare-version $base_version (token-to-minimum ($token | str substring 1..)).version) > 0)
  }
  if ($token starts-with '<=') {
    return ((compare-version $base_version (token-to-minimum ($token | str substring 2..)).version) <= 0)
  }
  if ($token starts-with '<') {
    return (version-lt $base_version (token-to-minimum ($token | str substring 1..)).version)
  }

  let prefix = if ($token starts-with '^') {
    '^'
  } else if ($token starts-with '~') {
    '~'
  } else {
    ''
  }
  let raw = if ($prefix | is-empty) { $token } else { $token | str substring 1.. }
  let requested = version-token-parts $raw
  let minimum = token-to-minimum $raw

  if not (version-gte $base_version $minimum.version) {
    return false
  }

  if $prefix == '^' {
    if $minimum.major > 0 {
      return (version-lt $base_version (semver-string ($minimum.major + 1) 0 0))
    }
    if $minimum.minor > 0 {
      return (version-lt $base_version (semver-string 0 ($minimum.minor + 1) 0))
    }
    return (version-lt $base_version (semver-string 0 0 ($minimum.patch + 1)))
  }

  if $prefix == '~' {
    if (wildcard-part $requested.minor) {
      return (version-lt $base_version (semver-string ($minimum.major + 1) 0 0))
    }
    return (version-lt $base_version (semver-string $minimum.major ($minimum.minor + 1) 0))
  }

  let actual = parse-comparable-semver $base_version
  if not (wildcard-part $requested.major) and ($actual.major != $minimum.major) {
    return false
  }
  if not (wildcard-part $requested.minor) and ($actual.minor != $minimum.minor) {
    return false
  }
  if not (wildcard-part $requested.patch) and ($actual.patch != $minimum.patch) {
    return false
  }

  true
}

export def version-satisfies-request [
  base_version: string,
  requested_version: string
]: nothing -> bool {
  let requested = $requested_version | str trim
  if ($requested | is-empty) {
    return true
  }

  if ($base_version == $requested) {
    return true
  }

  $requested
    | split row '||'
    | any {|range_group|
      let tokens = $range_group | str trim | split row ' ' | where {|token| $token | is-not-empty }
      if ($tokens | is-empty) {
        true
      } else {
        $tokens | all {|token| token-satisfies-version $base_version $token }
      }
    }
}

export def find-project-root [start_dir?: string]: nothing -> string {
  mut current = (if ($start_dir | is-not-empty) { $start_dir } else { pwd }) | path expand

  loop {
    let workspace_file = [$current 'pnpm-workspace.yaml'] | path join
    let lock_file = [$current 'pnpm-lock.yaml'] | path join
    if ($workspace_file | path exists) and ($lock_file | path exists) {
      return $current
    }

    let parent = $current | path dirname
    if $parent == $current {
      break
    }
    $current = $parent
  }

  ''
}

export def resolve-cli-path [input: string, base_dir?: string]: nothing -> string {
  let trimmed = $input | str trim
  if ($trimmed | is-empty) {
    return ''
  }

  if ($trimmed starts-with '/') or ($trimmed =~ '^[A-Za-z]:[\\/]') {
    return ($trimmed | path expand)
  }

  let base = if ($base_dir | is-not-empty) { $base_dir } else { pwd }
  [$base $trimmed] | path join | path expand
}

export def strip-lock-version-suffix [version: string]: nothing -> string {
  let trimmed = $version | str trim
  if ($trimmed | is-empty) {
    return ''
  }

  if ($trimmed | str contains '(') {
    $trimmed | split row '(' | first
  } else {
    $trimmed
  }
}

def parse-comparable-semver [version: string]: nothing -> record {
  parse-semver (normalize-comparable-version $version)
}

def normalize-dependency-entry [
  importer_id: string,
  dep_field: string,
  dep_name: string,
  dep_value: any
]: nothing -> record {
  let kind = $dep_value | describe
  let specifier = if ($kind starts-with 'record') {
    $dep_value | get -o specifier | default ''
  } else if ($kind == 'string') {
    $dep_value
  } else {
    ''
  }
  let version = if ($kind starts-with 'record') {
    $dep_value | get -o version | default ''
  } else if ($kind == 'string') {
    $dep_value
  } else {
    ''
  }
  let base_version = strip-lock-version-suffix $version

  {
    importer_id: $importer_id
    dep_field: $dep_field
    dep_name: $dep_name
    specifier: $specifier
    version: $version
    base_version: $base_version
    has_peer_suffix: ($version != $base_version)
  }
}

export def find-dependency-usages [
  project_root: string,
  dep_name: string,
  requested_version: string = ''
]: nothing -> list<record> {
  let lock_file = [$project_root 'pnpm-lock.yaml'] | path join
  let lock = open $lock_file
  let importers = $lock | get -o importers | default {}
  mut usages = []

  for importer_id in ($importers | columns | sort) {
    let importer = $importers | get $importer_id

    for dep_field in $DEP_FIELDS {
      let deps = $importer | get -o $dep_field | default {}
      if $dep_name in ($deps | columns) {
        let usage = normalize-dependency-entry $importer_id $dep_field $dep_name ($deps | get $dep_name)
        if ($usage.version | is-not-empty) {
          $usages = ($usages | append $usage)
        }
      }
    }
  }

  if ($requested_version | is-empty) {
    return $usages
  }

  $usages | where {|usage|
    ($usage.version == $requested_version) or (version-satisfies-request $usage.base_version $requested_version)
  }
}

def choose-ranked-entry [
  ranked: list<record>,
  strategy: string
]: nothing -> record {
  if ($ranked | is-empty) {
    return {}
  }

  match $strategy {
    'most-common' => ($ranked | first)
    'highest' => (
      $ranked
        | sort-by major minor patch count version --reverse
        | first
    )
    _ => {
      err $'Error: Unsupported version strategy `($strategy)`'
      exit 1
    }
  }
}

export def rank-dependency-usages [
  usages: list<record>,
  strategy: string = 'most-common'
]: nothing -> list<record> {
  if ($usages | is-empty) {
    return []
  }

  let ranked = $usages
    | group-by version
    | transpose version matches
    | upsert count {|row| $row.matches | length }
    | upsert base_version {|row| $row.matches.0.base_version }
    | upsert parts {|row| parse-comparable-semver $row.base_version }
    | upsert major {|row| $row.parts.major }
    | upsert minor {|row| $row.parts.minor }
    | upsert patch {|row| $row.parts.patch }
    | upsert importers {|row| $row.matches | get importer_id | uniq | sort }
    | upsert observed_specifiers {|row| $row.matches | get specifier | uniq | sort }
    | sort-by count major minor patch version --reverse

  let selected = choose-ranked-entry $ranked $strategy
  if ($selected | is-empty) {
    return $ranked
  }

  $ranked | upsert selected {|row| $row.version == ($selected | get version) }
}

export def choose-installed-resolution-from-lockfile [
  project_root: string,
  dep_name: string,
  strategy: string = 'most-common',
  requested_version: string = ''
]: nothing -> record {
  let usages = find-dependency-usages $project_root $dep_name $requested_version

  if ($usages | is-empty) {
    return {
      found: false
      dep_name: $dep_name
      requested_version: $requested_version
      candidates: []
    }
  }

  let ranked = rank-dependency-usages $usages $strategy
  let chosen = $ranked | where selected == true | first

  {
    found: true
    dep_name: $dep_name
    requested_version: $requested_version
    specifier: ($chosen.base_version)
    version: ($chosen.version)
    base_version: ($chosen.base_version)
    count: ($chosen.count)
    importers: ($chosen.importers)
    observed_specifiers: ($chosen.observed_specifiers)
    usages: ($chosen.matches)
    candidates: $ranked
  }
}

def render-summary [resolution: record, project_root: string] {
  info $'Project root: ($project_root)'
  info $'Dependency: ($resolution.dep_name)'

  if (($resolution.requested_version | default '') | is-not-empty) {
    info $'Requested version filter: ($resolution.requested_version)'
  }

  success $'Selected lockfile version: ($resolution.version)'
  success $'Package.json specifier to reuse: ($resolution.specifier)'
}

def render-candidate-table [resolution: record] {
  let candidates = $resolution.candidates
    | each {|row|
      {
        selected: (if $row.selected { '*' } else { '' })
        version: $row.version
        base_version: $row.base_version
        count: $row.count
        specifiers: ($row.observed_specifiers | str join ', ')
        importers: ($row.importers | length)
      }
    }

  if ($candidates | is-not-empty) {
    print ''
    print 'Version candidates:'
    $candidates | print
  }
}

def render-usage-table [resolution: record] {
  let usages = $resolution.usages
    | each {|row|
      {
        importer: $row.importer_id
        field: $row.dep_field
        specifier: $row.specifier
        version: $row.version
      }
    }
    | sort-by importer field

  if ($usages | is-not-empty) {
    print ''
    print 'Selected version is currently used by:'
    $usages | print
  }
}

@example 'Show all lockfile candidates for a dependency already used in the workspace' {
  t pnpm-why dayjs
} --result 'Prints the selected version, all observed lockfile candidates, and the importers currently using the selected version'
@example 'Filter by a requested base version and inspect exact peer-qualified lockfile entries' {
  t pnpm-why @alife/hooks@1.1.1
} --result 'Shows which exact lockfile version of @alife/hooks@1.1.1 is selected and where it is already referenced'
@example 'Return machine-readable resolution data for use by other scripts' {
  t pnpm-why got@13 --json
} --result 'Outputs a JSON record containing the chosen version plus all candidate versions and importer usages'
def main [
  dependency_spec: string,                    # dependency name or name@version; reads pnpm-lock.yaml directly instead of calling pnpm why
  --project-root (-r): string,                # Workspace root, defaults to nearest ancestor with pnpm-workspace.yaml
  --version-strategy: string = 'most-common', # How to pick the preferred candidate: most-common | highest
  --json                                      # Print machine-readable JSON with candidates/usages instead of a table view
] {
  $env.config.table.mode = 'psql'
  let parsed = parse-package-spec $dependency_spec
  if ($parsed.name | is-empty) {
    err $'Error: Invalid dependency specification. (ordinary-npm-spec-error-message)'
    exit 1
  }

  let root = if ($project_root | is-not-empty) {
    resolve-cli-path $project_root
  } else {
    find-project-root
  }

  if ($root | is-empty) {
    err 'Error: Could not find project root with pnpm-workspace.yaml and pnpm-lock.yaml'
    exit 1
  }

  let resolution = choose-installed-resolution-from-lockfile $root $parsed.name $version_strategy $parsed.version

  if not $resolution.found {
    err $'Error: No lockfile entries for `($dependency_spec)` were found in ($root)'
    exit 1
  }

  if $json {
    print ($resolution | to json -r)
    return
  }

  render-summary $resolution $root
  render-candidate-table $resolution
  render-usage-table $resolution
}
