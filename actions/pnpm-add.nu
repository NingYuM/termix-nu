#!/usr/bin/env nu

# Offline pnpm add tool - add a dependency to one workspace package without
# re-resolving the full workspace.
#
# Usage examples:
#   nu pnpm-add.nu dayjs --package-dir pkgs/b_order_detail
#   nu pnpm-add.nu dayjs@1.11.10 --package-dir pkgs/b_order_detail/resources
#   nu pnpm-add.nu got@13 --package-dir pkgs/p_slc_supplier_inspect_create/resources
#
# This script is intentionally conservative:
# 1. It prefers versions that are already present in pnpm-lock.yaml importers.
# 2. It only updates the target importer's dependency block in pnpm-lock.yaml.
# 3. It falls back to an isolated pnpm add only when the dependency is absent
#    from the workspace lockfile, then merges the isolated dependency tree.
# 4. It recommends Node 20 and pnpm 9, and uses the current shell's node/pnpm runtime.

use ../utils/pnpm-lock.nu [
  assert-snapshot-dependency-closure
  find-missing-snapshot-dependency-entries
  has-lockfile-entry
  lockfile-entry-key
  merge-lockfile-section-entries
  select-reachable-snapshot-entries
  write-lockfile-via-pnpm-bundle
  upsert-importer-dependency-record
]
use ./pnpm-why.nu [
  choose-installed-resolution-from-lockfile
  ordinary-npm-spec-error-message
  parse-package-spec
  strip-lock-version-suffix
  version-satisfies-request
]
use ../utils/common.nu [is-lower-ver]

def err [msg: string] { print -e $'(ansi r)($msg)(ansi rst)' }
def warn [msg: string] { print $'(ansi y)($msg)(ansi rst)' }
def info [msg: string] { print $'(ansi c)($msg)(ansi rst)' }
def success [msg: string] { print $'(ansi g)($msg)(ansi rst)' }

const DEP_FIELDS = ['dependencies' 'optionalDependencies' 'devDependencies']
const DEP_FIELD_ORDER = ['dependencies' 'optionalDependencies' 'devDependencies']
const MIN_PNPM_VERSION = '9.13.0'
const PNPM_UPGRADE_COMMAND = 'npm i -g pnpm@9'

def assert-min-pnpm-version [pnpm_version: string] {
  if (is-lower-ver $pnpm_version $MIN_PNPM_VERSION) {
    err $'Error: pnpm ($pnpm_version) is lower than the required version ($MIN_PNPM_VERSION).'
    err $'Please upgrade pnpm with `($PNPM_UPGRADE_COMMAND)` to use the latest pnpm 9 version.'
    exit 1
  }
}

def assert-runtime [] {
  let node_version = try { ^node --version | str trim } catch { '' }
  let pnpm_version = try { ^pnpm --version | str trim } catch { '' }

  if ($node_version | is-empty) {
    err 'Error: `node` is not available in the current shell.'
    exit 1
  }

  if ($pnpm_version | is-empty) {
    err 'Error: `pnpm` is not available in the current shell.'
    exit 1
  }

  assert-min-pnpm-version $pnpm_version

  let pnpm_major = $pnpm_version | split row '.' | first | into int

  if ($node_version starts-with 'v20.') and ($pnpm_major == 9) {
    success $'Runtime OK: node ($node_version), pnpm ($pnpm_version)'
  } else {
    warn $'Runtime warning: current shell uses node ($node_version), pnpm ($pnpm_version); node 20 + pnpm 9 is the recommended combination for this script.'
  }
}

def find-project-root [start_dir?: string]: nothing -> string {
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

def invocation-dir []: nothing -> string {
  $env.JUST_INVOKE_DIR? | default (pwd)
}

def resolve-cli-path [input: string, base_dir?: string]: nothing -> string {
  let trimmed = $input | str trim
  if ($trimmed | is-empty) {
    return ''
  }

  if ($trimmed starts-with '/') or ($trimmed =~ '^[A-Za-z]:[\\/]') {
    return ($trimmed | path expand)
  }

  let base = if ($base_dir | is-not-empty) { $base_dir } else { invocation-dir }
  [$base $trimmed] | path join | path expand
}

def list-candidate-package-dirs [project_root: string, start_dir: string]: nothing -> list<string> {
  let abs_start = $start_dir | path expand
  mut candidates = []
  mut current = $abs_start

  loop {
    let direct_pkg = [$current 'package.json'] | path join
    if ($direct_pkg | path exists) {
      $candidates = ($candidates | append $current)
    }

    let resources_dir = [$current 'resources'] | path join
    let resources_pkg = [$resources_dir 'package.json'] | path join
    if ($resources_pkg | path exists) {
      $candidates = ($candidates | append $resources_dir)
    }

    if $current == $project_root {
      break
    }

    let parent = $current | path dirname
    if $parent == $current {
      break
    }
    $current = $parent
  }

  $candidates | uniq
}

def resolve-target-package [
  project_root: string,
  lock_content: string,
  package_dir?: string
] {
  let start_dir = if ($package_dir | is-not-empty) {
    resolve-cli-path $package_dir $project_root
  } else {
    invocation-dir
  }
  let candidates = list-candidate-package-dirs $project_root $start_dir

  for candidate in $candidates {
    let importer_id = $candidate | path relative-to $project_root | str replace -a '\' '/'
    let importer_line = $'  ($importer_id):'
    let empty_importer_line = $'  ($importer_id): {}'

    if ($lock_content has $importer_line) or ($lock_content has $empty_importer_line) {
      return {
        package_dir: $candidate
        package_json: ([$candidate 'package.json'] | path join)
        importer_id: $importer_id
      }
    }
  }

  err $'Error: Could not resolve a workspace package from ($start_dir)'
  err 'Hint: pass --package-dir with the package root or the resources directory.'
  exit 1
}

def sort-record-keys [input: record]: nothing -> record {
  let keys = $input | columns | sort
  mut result = {}

  for key in $keys {
    $result = ($result | upsert $key ($input | get $key))
  }

  $result
}

def cleanup-temp-dir [tmp_dir: string] {
  if ($tmp_dir | path exists) {
    rm -rf $tmp_dir
  }
}

def update-package-json [
  package_json: string,
  dep_field: string,
  dep_name: string,
  specifier: string,
  --dry-run
]: nothing -> record<updated: bool, old_value: string> {
  let pkg = open $package_json
  let current_deps = $pkg | get -o $dep_field | default {}
  let old_value = $current_deps | get -o $dep_name | default ''
  let duplicate_fields = $DEP_FIELDS
    | where {|field|
      ($field != $dep_field) and ($dep_name in (($pkg | get -o $field | default {}) | columns))
    }

  if ($old_value == $specifier) and ($duplicate_fields | is-empty) {
    return { updated: false, old_value: $old_value }
  }

  mut updated_pkg = $pkg

  for field in $duplicate_fields {
    let other_deps = $updated_pkg | get -o $field | default {}
    let next_other_deps = sort-record-keys ($other_deps | reject $dep_name)
    $updated_pkg = if ($next_other_deps | is-empty) {
      $updated_pkg | reject $field
    } else {
      $updated_pkg | update $field $next_other_deps
    }
  }

  let target_deps = $updated_pkg | get -o $dep_field | default {}
  let updated_deps = sort-record-keys ($target_deps | upsert $dep_name $specifier)
  $updated_pkg = if ($updated_pkg | get -o $dep_field | is-empty) {
    $updated_pkg | insert $dep_field $updated_deps
  } else {
    $updated_pkg | update $dep_field $updated_deps
  }

  if not $dry_run {
    $updated_pkg | save -f $package_json
  }

  { updated: true, old_value: $old_value }
}

def field-to-save-flag [dep_field: string]: nothing -> string {
  match $dep_field {
    'devDependencies' => '--save-dev'
    'optionalDependencies' => '--save-optional'
    _ => ''
  }
}

def dependency-spec-for-exact-version [
  dep_name: string,
  version: string
]: nothing -> string {
  $'($dep_name)@(strip-lock-version-suffix $version)'
}

def resolve-dependency-in-isolated-project [
  project_root: string,
  dependency_spec: string,
  dep_field: string,
  dep_name: string
] {
  let tmp_dir = (^mktemp -d | str trim)
  let temp_manifest = { name: 'termix-pnpm-add-tmp', version: '1.0.0' }
  let temp_manifest_path = [$tmp_dir 'package.json'] | path join
  $temp_manifest | save -f $temp_manifest_path

  let root_npmrc = [$project_root '.npmrc'] | path join
  if ($root_npmrc | path exists) {
    cp $root_npmrc ([$tmp_dir '.npmrc'] | path join)
  }

  let save_flag = field-to-save-flag $dep_field
  let pnpm_args = [
    'add'
    $dependency_spec
    '--lockfile-only'
    '--ignore-workspace'
    '--ignore-scripts'
    '--save-exact'
  ]
  let pnpm_args = if ($save_flag | is-not-empty) {
    $pnpm_args | append $save_flag
  } else {
    $pnpm_args
  }

  let result = do {
    cd $tmp_dir
    ^pnpm ...$pnpm_args
  } | complete

  if $result.exit_code != 0 {
    err $'Error: failed to resolve `($dependency_spec)` in isolated pnpm project'
    if ($result.stdout | str trim | is-not-empty) {
      print $result.stdout
    }
    if ($result.stderr | str trim | is-not-empty) {
      print -e $result.stderr
    }
    if (not ($dependency_spec | str contains '@')) or (($dependency_spec starts-with '@') and (($dependency_spec | split row '@' | length) == 2)) {
      warn 'Hint: the latest version may not satisfy Node 20 or your registry policy; try an explicit version such as `got@13`.'
    }
    cleanup-temp-dir $tmp_dir
    exit 1
  }

  let resolved_manifest = open $temp_manifest_path
  let resolved_lock_path = [$tmp_dir 'pnpm-lock.yaml'] | path join
  let resolved_lock = open $resolved_lock_path

  let resolved_specifier = $resolved_manifest | get $dep_field | get $dep_name
  let importer_info = $resolved_lock | get importers | get "." | get $dep_field | get $dep_name
  let resolved_version = $importer_info | get version
  let resolved = {
    specifier: $resolved_specifier
    version: $resolved_version
    package_entries: ($resolved_lock | get -o packages | default {})
    snapshot_entries: ($resolved_lock | get -o snapshots | default {})
  }

  cleanup-temp-dir $tmp_dir
  $resolved
}

def get-importer-dependency-resolution [
  lock_data: record,
  importer_id: string,
  dep_field: string,
  dep_name: string
]: nothing -> record {
  let importer = $lock_data | get -o importers | default {} | get -o $importer_id
  if ($importer | is-empty) {
    return { found: false }
  }

  let deps = $importer | get -o $dep_field | default {}
  if $dep_name not-in ($deps | columns) {
    return { found: false }
  }

  let entry = $deps | get $dep_name
  let kind = $entry | describe
  let version = if ($kind starts-with 'record') {
    $entry | get -o version | default ''
  } else {
    $entry | into string
  }
  let raw_specifier = if ($kind starts-with 'record') {
    $entry | get -o specifier | default ''
  } else {
    ''
  }
  let specifier = if ($raw_specifier | is-not-empty) {
    $raw_specifier
  } else {
    strip-lock-version-suffix $version
  }

  {
    found: true
    specifier: $specifier
    version: $version
    base_version: (strip-lock-version-suffix $version)
  }
}

def filter-record-by-keys [
  entries: record,
  keys: list<string>
]: nothing -> record {
  if ($entries | is-empty) or ($keys | is-empty) {
    return {}
  }

  mut selected = {}
  for key in ($entries | columns) {
    if $key in $keys {
      $selected = ($selected | upsert $key ($entries | get $key))
    }
  }

  $selected
}

def update-lockfile [
  lock_file: string,
  importer_id: string,
  dep_field: string,
  dep_name: string,
  specifier: string,
  version: string,
  incoming_package_entries?: record,
  incoming_snapshot_entries?: record,
  --dry-run
] {
  let lock_data = open $lock_file
  let package_version = strip-lock-version-suffix $version
  let root_snapshot_key = lockfile-entry-key $dep_name $version

  mut next_lock = $lock_data
  mut lock_updated = false

  let required_snapshot_entries = select-reachable-snapshot-entries $next_lock ($incoming_snapshot_entries | default {}) [$root_snapshot_key]
  let snapshot_merge = merge-lockfile-section-entries $next_lock 'snapshots' $required_snapshot_entries
  if $snapshot_merge.updated {
    $next_lock = $snapshot_merge.lock
    $lock_updated = true
  }

  let missing_package_keys = (find-missing-snapshot-dependency-entries $next_lock [$root_snapshot_key]
    | where missing_section == 'packages'
    | get -o missing_key
    | default []
    | append (lockfile-entry-key $dep_name $package_version)
    | uniq)
  let required_package_entries = filter-record-by-keys ($incoming_package_entries | default {}) $missing_package_keys
  let package_merge = merge-lockfile-section-entries $next_lock 'packages' $required_package_entries
  if $package_merge.updated {
    $next_lock = $package_merge.lock
    $lock_updated = true
  }

  if not (has-lockfile-entry $next_lock 'packages' $dep_name $package_version) {
    err $'Error: pnpm-lock.yaml does not contain packages entry for ($dep_name)@($package_version)'
    err 'Hint: choose a version that is already installed in this workspace or let pnpm-add resolve it in isolation.'
    exit 1
  }

  if not (has-lockfile-entry $next_lock 'snapshots' $dep_name $version) {
    err $'Error: pnpm-lock.yaml does not contain snapshots entry for ($dep_name)@($version)'
    err 'Hint: choose a version that is already installed in this workspace or let pnpm-add resolve it in isolation.'
    exit 1
  }

  let result = upsert-importer-dependency-record $next_lock $importer_id $dep_field $dep_name $specifier $version $DEP_FIELDS
  if $result.updated {
    $next_lock = $result.lock
    $lock_updated = true
  }

  assert-snapshot-dependency-closure $next_lock [$root_snapshot_key]

  if not $lock_updated {
    return false
  }

  write-lockfile-via-pnpm-bundle $lock_file $next_lock --dry-run=$dry_run

  true
}

# Offline add for one workspace package using lockfile-first reuse.
#
# The dependency version is chosen from workspace lockfile importer entries when
# possible, and falls back to isolated resolution only when necessary.
@example 'Reuse the most common version already present in the workspace lockfile' {
  t pnpm-add dayjs --package-dir pkgs/b_order_detail
} --result 'Adds dayjs to pkgs/b_order_detail/resources/package.json and updates its importer entry in pnpm-lock.yaml'
@example 'Reuse a specific version already present in the workspace lockfile' {
  t pnpm-add dayjs@1.11.10 --package-dir pkgs/b_order_detail/resources
} --result 'Writes specifier/version 1.11.10 without touching packages or snapshots sections'
@example 'Resolve a version in an isolated pnpm project when the workspace does not already contain it' {
  t pnpm-add got@13 --package-dir pkgs/p_slc_supplier_inspect_create/resources
} --result 'Adds got@13 to the target package and merges the resolved packages/snapshots entries into pnpm-lock.yaml'
def main [
  dependency_spec: string,                 # name or name@version; resolves from workspace lockfile first, then isolated pnpm if needed
  --package-dir (-p): string,             # Workspace package dir or parent module dir, defaults to cwd
  --project-root (-r): string,            # Workspace root, defaults to nearest ancestor of JUST_INVOKE_DIR/pwd with pnpm-workspace.yaml
  --field (-f): string = 'dependencies',  # dependencies | optionalDependencies | devDependencies
  --version-strategy: string = 'most-common',  # How to choose among existing lockfile candidates: most-common | highest
  --dry-run                              # Show planned changes without writing files
] {
  assert-runtime

  if $field not-in $DEP_FIELDS {
    err $'Error: Unsupported dependency field `($field)`'
    exit 1
  }

  let parsed = parse-package-spec $dependency_spec
  if ($parsed.name | is-empty) {
    err $'Error: Invalid dependency specification. (ordinary-npm-spec-error-message)'
    exit 1
  }

  let root = if ($project_root | is-not-empty) {
    resolve-cli-path $project_root
  } else {
    find-project-root (invocation-dir)
  }

  if ($root | is-empty) {
    err 'Error: Could not find project root with pnpm-workspace.yaml and pnpm-lock.yaml'
    exit 1
  }

  let lock_file = [$root 'pnpm-lock.yaml'] | path join
  let lock_content = open $lock_file --raw | decode utf-8
  let lock_data = open $lock_file
  let target = resolve-target-package $root $lock_content $package_dir
  let existing_target_resolution = get-importer-dependency-resolution $lock_data $target.importer_id $field $parsed.name
  let can_reuse_target_resolution = $existing_target_resolution.found and (
    ($parsed.version | is-empty) or
    ($existing_target_resolution.version == $parsed.version) or
    (version-satisfies-request $existing_target_resolution.base_version $parsed.version)
  )
  let lockfile_resolution = if $can_reuse_target_resolution {
    {
      found: true
      specifier: ($existing_target_resolution.specifier)
      version: ($existing_target_resolution.version)
    }
  } else {
    choose-installed-resolution-from-lockfile $root $parsed.name $version_strategy $parsed.version
  }
  let lockfile_closure_missing = if $lockfile_resolution.found {
    let root_snapshot_key = lockfile-entry-key $parsed.name $lockfile_resolution.version
    not (find-missing-snapshot-dependency-entries $lock_data [$root_snapshot_key] | is-empty)
  } else {
    false
  }
  let should_resolve_in_isolation = (not $lockfile_resolution.found) or $lockfile_closure_missing
  let isolated_resolution = if $should_resolve_in_isolation {
    let spec_to_resolve = if $lockfile_resolution.found {
      dependency-spec-for-exact-version $parsed.name $lockfile_resolution.version
    } else {
      $dependency_spec
    }
    if $lockfile_closure_missing {
      warn $'Dependency ($parsed.name) exists in pnpm-lock.yaml, but its snapshot dependency closure is incomplete; resolving ($spec_to_resolve) in an isolated pnpm project...'
    } else {
      info $'Dependency ($dependency_spec) is not present in the workspace lockfile, resolving it in an isolated pnpm project...'
    }
    let resolved = resolve-dependency-in-isolated-project $root $spec_to_resolve $field $parsed.name
    if $lockfile_resolution.found {
      $resolved | update specifier $lockfile_resolution.specifier | update version $lockfile_resolution.version
    } else {
      $resolved
    }
  } else {
    {
      specifier: ($lockfile_resolution.specifier)
      version: ($lockfile_resolution.version)
      package_entries: {}
      snapshot_entries: {}
    }
  }

  let package_json = $target.package_json
  let specifier = $isolated_resolution.specifier
  let version = $isolated_resolution.version

  info $'Project root: ($root)'
  info $'Target package: ($target.importer_id)'
  info $'Dependency field: ($field)'
  info $'Dependency: ($parsed.name)@($version)'

  let pkg_result = update-package-json $package_json $field $parsed.name $specifier --dry-run=$dry_run
  let lock_updated = update-lockfile $lock_file $target.importer_id $field $parsed.name $specifier $version $isolated_resolution.package_entries $isolated_resolution.snapshot_entries --dry-run=$dry_run

  if $dry_run {
    success 'Dry run completed'
  } else {
    success 'Offline add completed'
  }

  if $pkg_result.updated {
    success $'Updated package.json: ($package_json)'
  } else {
    info 'package.json already contained the requested dependency'
  }

  if $lock_updated {
    success $'Updated pnpm-lock.yaml importer: ($target.importer_id)'
  } else {
    info 'pnpm-lock.yaml already contained the requested importer entry'
  }
}
