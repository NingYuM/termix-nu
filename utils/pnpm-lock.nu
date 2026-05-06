#!/usr/bin/env nu

def err [msg: string] { print -e $'(ansi r)($msg)(ansi rst)' }

def cleanup-temp-dir [tmp_dir: string] {
  if ($tmp_dir | path exists) {
    rm -rf $tmp_dir
  }
}

def lockfile-base-version [version: string]: nothing -> string {
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

export def lockfile-entry-key [
  dep_name: string,
  version: string
]: nothing -> string {
  $'($dep_name)@($version)'
}

export def has-lockfile-entry [
  lock_data: record,
  section_name: string,
  dep_name: string,
  version: string
]: nothing -> bool {
  let section = $lock_data | get -o $section_name | default {}
  let key = lockfile-entry-key $dep_name $version
  $key in ($section | columns)
}

def should-check-snapshot-dependency-version [version: string]: nothing -> bool {
  let trimmed = $version | str trim
  if ($trimmed | is-empty) {
    return false
  }

  let skipped_prefixes = ['link:' 'file:' 'workspace:' 'catalog:']
  ($skipped_prefixes | where {|prefix| $trimmed starts-with $prefix } | is-empty)
}

def snapshot-dependency-entries [
  snapshot_key: string,
  snapshot: record
]: nothing -> list<record> {
  let dependencies = $snapshot | get -o dependencies | default {}
  let optional_dependencies = $snapshot | get -o optionalDependencies | default {}
  let all_dependencies = $dependencies | merge $optional_dependencies

  $all_dependencies
    | transpose dep_name version
    | where {|entry| should-check-snapshot-dependency-version ($entry.version | into string) }
    | each {|entry|
      let dep_version = $entry.version | into string
      {
        from: $snapshot_key
        dep_name: $entry.dep_name
        version: $dep_version
        package_key: (lockfile-entry-key $entry.dep_name (lockfile-base-version $dep_version))
        snapshot_key: (lockfile-entry-key $entry.dep_name $dep_version)
      }
    }
}

export def find-missing-snapshot-dependency-entries [
  lock_data: record,
  root_snapshot_keys: list<string>
]: nothing -> list<record> {
  let packages = $lock_data | get -o packages | default {}
  let snapshots = $lock_data | get -o snapshots | default {}
  let package_keys = $packages | columns
  let snapshot_keys = $snapshots | columns
  mut queue = $root_snapshot_keys
  mut seen = []
  mut missing = []

  loop {
    if ($queue | is-empty) {
      break
    }

    let current = $queue | first
    $queue = ($queue | skip 1)

    if $current in $seen {
      continue
    }

    if $current not-in $snapshot_keys {
      $missing = ($missing | append {
        from: ''
        dep_name: ''
        version: ''
        missing_section: 'snapshots'
        missing_key: $current
      })
      $seen = ($seen | append $current)
      continue
    }

    $seen = ($seen | append $current)
    let snapshot = $snapshots | get $current
    let dependencies = snapshot-dependency-entries $current $snapshot

    for dependency in $dependencies {
      if $dependency.package_key not-in $package_keys {
        $missing = ($missing | append {
          from: $dependency.from
          dep_name: $dependency.dep_name
          version: $dependency.version
          missing_section: 'packages'
          missing_key: $dependency.package_key
        })
      }

      if $dependency.snapshot_key not-in $snapshot_keys {
        $missing = ($missing | append {
          from: $dependency.from
          dep_name: $dependency.dep_name
          version: $dependency.version
          missing_section: 'snapshots'
          missing_key: $dependency.snapshot_key
        })
      } else if ($dependency.snapshot_key not-in $seen) and ($dependency.snapshot_key not-in $queue) {
        $queue = ($queue | append $dependency.snapshot_key)
      }
    }
  }

  $missing
}

export def assert-snapshot-dependency-closure [
  lock_data: record,
  root_snapshot_keys: list<string>
] {
  let missing = find-missing-snapshot-dependency-entries $lock_data $root_snapshot_keys

  if ($missing | is-empty) {
    return
  }

  err 'Error: pnpm-lock.yaml is missing entries required by snapshot dependencies'
  $missing
    | first 20
    | each {|entry|
      if ($entry.from | is-empty) {
        err $'  Missing ($entry.missing_section) entry `($entry.missing_key)`'
      } else {
        err $'  ($entry.from) -> ($entry.dep_name)@($entry.version) is missing ($entry.missing_section) entry `($entry.missing_key)`'
      }
    }

  if (($missing | length) > 20) {
    err $'  ... and (($missing | length) - 20) more missing entries'
  }

  exit 1
}

export def merge-lockfile-section-entries [
  lock_data: record,
  section_name: string,
  incoming_entries: record
]: nothing -> record<updated: bool, lock: record> {
  if ($incoming_entries | is-empty) {
    return { updated: false, lock: $lock_data }
  }

  let section = $lock_data | get -o $section_name | default {}
  mut next_section = $section
  mut updated = false

  for key in ($incoming_entries | columns) {
    let incoming = $incoming_entries | get $key
    if $key not-in ($section | columns) {
      $next_section = ($next_section | upsert $key $incoming)
      $updated = true
      continue
    }

    let existing = $section | get $key
    if $existing != $incoming {
      err $'Error: existing ($section_name) entry `($key)` differs from the incoming lockfile data'
      exit 1
    }
  }

  if not $updated {
    return { updated: false, lock: $lock_data }
  }

  {
    updated: true
    lock: ($lock_data | upsert $section_name $next_section)
  }
}

export def select-reachable-snapshot-entries [
  lock_data: record,
  incoming_entries: record,
  root_snapshot_keys: list<string>
]: nothing -> record {
  if ($incoming_entries | is-empty) or ($root_snapshot_keys | is-empty) {
    return {}
  }

  let existing_snapshots = $lock_data | get -o snapshots | default {}
  let existing_keys = $existing_snapshots | columns
  let incoming_keys = $incoming_entries | columns
  mut queue = $root_snapshot_keys
  mut seen = []
  mut selected = {}

  loop {
    if ($queue | is-empty) {
      break
    }

    let current = $queue | first
    $queue = ($queue | skip 1)

    if $current in $seen {
      continue
    }
    $seen = ($seen | append $current)

    let snapshot = if $current in $existing_keys {
      $existing_snapshots | get $current
    } else if $current in $incoming_keys {
      let incoming = $incoming_entries | get $current
      $selected = ($selected | upsert $current $incoming)
      $incoming
    } else {
      continue
    }

    for dependency in (snapshot-dependency-entries $current $snapshot) {
      if ($dependency.snapshot_key not-in $seen) and ($dependency.snapshot_key not-in $queue) {
        $queue = ($queue | append $dependency.snapshot_key)
      }
    }
  }

  $selected
}

export def upsert-importer-dependency-record [
  lock_data: record,
  importer_id: string,
  dep_field: string,
  dep_name: string,
  specifier: string,
  version: string,
  dep_fields: list<string> = []
]: nothing -> record<updated: bool, lock: record> {
  let importers = $lock_data | get -o importers | default {}
  let importer = $importers | get -o $importer_id

  if ($importer | is-empty) {
    return { updated: false, lock: $lock_data }
  }

  let fields_to_clean = if ($dep_fields | is-empty) { [$dep_field] } else { $dep_fields }
  mut next_importer = $importer

  for field in $fields_to_clean {
    if $field == $dep_field {
      continue
    }

    let other_deps = $next_importer | get -o $field | default {}
    if $dep_name not-in ($other_deps | columns) {
      continue
    }

    let next_other_deps = $other_deps | reject $dep_name
    $next_importer = if ($next_other_deps | is-empty) {
      $next_importer | reject $field
    } else {
      $next_importer | update $field $next_other_deps
    }
  }

  let deps = $next_importer | get -o $dep_field | default {}
  let desired = { specifier: $specifier, version: $version }

  $next_importer = if $dep_field in ($next_importer | columns) {
    $next_importer | update $dep_field ($deps | upsert $dep_name $desired)
  } else {
    $next_importer | insert $dep_field ($deps | upsert $dep_name $desired)
  }

  if $next_importer == $importer {
    return { updated: false, lock: $lock_data }
  }

  let next_importers = $importers | upsert $importer_id $next_importer

  {
    updated: true
    lock: ($lock_data | upsert importers $next_importers)
  }
}

export def upsert-root-patched-dependency-record [
  lock_data: record,
  patch_key: string,
  patch_hash: string,
  patch_path: string
]: nothing -> record<updated: bool, old_hash: string, lock: record> {
  let patched_dependencies = $lock_data | get -o patchedDependencies | default {}
  let current = $patched_dependencies | get -o $patch_key | default null
  let old_hash = if ($current | describe | str starts-with 'record') {
    $current | get -o hash | default ''
  } else {
    ''
  }
  let desired = { hash: $patch_hash, path: $patch_path }

  if ($current != null) and ($current == $desired) {
    return { updated: false, old_hash: $old_hash, lock: $lock_data }
  }

  let next_lock = if 'patchedDependencies' in ($lock_data | columns) {
    $lock_data | update patchedDependencies ($patched_dependencies | upsert $patch_key $desired)
  } else {
    $lock_data | insert patchedDependencies { $patch_key: $desired }
  }

  {
    updated: true
    old_hash: $old_hash
    lock: $next_lock
  }
}

def pnpm-bundle-path []: nothing -> string {
  let pnpm_bin = try { ^which pnpm | str trim } catch { '' }
  let pnpm_real_bin = if ($pnpm_bin | is-not-empty) {
    try { $pnpm_bin | path expand } catch { $pnpm_bin }
  } else {
    ''
  }
  let npm_root = try { ^npm root -g | str trim } catch { '' }
  let candidates = [
    (if ($npm_root | is-not-empty) { [$npm_root 'pnpm/dist/pnpm.cjs'] | path join } else { '' })
    (if ($pnpm_bin | is-not-empty) { [($pnpm_bin | path dirname) '../lib/node_modules/pnpm/dist/pnpm.cjs'] | path join } else { '' })
    (if ($pnpm_real_bin | is-not-empty) { [($pnpm_real_bin | path dirname) '../lib/node_modules/pnpm/dist/pnpm.cjs'] | path join } else { '' })
  ] | where {|it| $it | is-not-empty } | uniq

  for candidate in $candidates {
    let resolved = $candidate | path expand
    if ($resolved | path exists) {
      return $resolved
    }
  }

  err 'Error: Could not locate pnpm/dist/pnpm.cjs from the current runtime. Please ensure pnpm is installed in the current shell.'
  ''
}

def pnpm-lock-writer-script []: nothing -> string {
  [
    "const fs = require('fs');"
    "const path = require('path');"
    "const vm = require('vm');"
    ""
    "const [bundlePath, lockFilePath, jsonPath] = process.argv.slice(2);"
    "if (!bundlePath || !lockFilePath || !jsonPath) {"
    "  throw new Error('Usage: node pnpm-lock-writer.cjs <pnpm-bundle> <lock-file> <json-file>');"
    "}"
    ""
    "let code = fs.readFileSync(bundlePath, 'utf8');"
    "const marker = 'process.setMaxListeners(0);';"
    "const idx = code.lastIndexOf(marker);"
    "if (idx === -1) {"
    "  throw new Error('Could not find pnpm CLI bootstrap marker in bundle');"
    "}"
    ""
    "code = code.slice(0, idx) + `"
    "module.exports = {"
    "  writeLockfileFromJson: async (targetPath, jsonString) => {"
    "    const { writeLockfileFile } = require_write();"
    "    return writeLockfileFile(targetPath, JSON.parse(jsonString));"
    "  }"
    "};"
    "`;"
    ""
    "const sandbox = {"
    "  require,"
    "  module: { exports: {} },"
    "  exports: {},"
    "  process,"
    "  console,"
    "  Buffer,"
    "  setTimeout,"
    "  clearTimeout,"
    "  setImmediate,"
    "  clearImmediate,"
    "  URL,"
    "  URLSearchParams,"
    "  TextEncoder,"
    "  TextDecoder,"
    "  performance,"
    "  __filename: bundlePath,"
    "  __dirname: path.dirname(bundlePath),"
    "};"
    "sandbox.global = sandbox;"
    "sandbox.globalThis = sandbox;"
    ""
    "vm.runInNewContext(code, sandbox, { filename: bundlePath });"
    ""
    "const { writeLockfileFromJson } = sandbox.module.exports;"
    "const jsonString = fs.readFileSync(jsonPath, 'utf8');"
    ""
    "Promise.resolve(writeLockfileFromJson(lockFilePath, jsonString)).catch((error) => {"
    "  console.error(error);"
    "  process.exit(1);"
    "});"
  ] | str join (char nl)
}

export def write-lockfile-via-pnpm-bundle [
  lock_file: string,
  lock_data: record,
  --dry-run
] {
  let tmp_dir = (^mktemp -d | str trim)
  let json_file = [$tmp_dir 'pnpm-lock.json'] | path join
  let script_file = [$tmp_dir 'pnpm-lock-writer.cjs'] | path join
  let output_file = if $dry_run { [$tmp_dir 'pnpm-lock.yaml'] | path join } else { $lock_file }
  let bundle_path = pnpm-bundle-path

  if ($bundle_path | is-empty) {
    cleanup-temp-dir $tmp_dir
    exit 1
  }

  ($lock_data | to json -r) | save -f $json_file
  (pnpm-lock-writer-script) | save -f $script_file

  let result = do {
    ^node $script_file $bundle_path $output_file $json_file
  } | complete

  if $result.exit_code != 0 {
    err 'Error: failed to serialize pnpm-lock.yaml via pnpm bundle writer'
    if ($result.stdout | str trim | is-not-empty) {
      print $result.stdout
    }
    if ($result.stderr | str trim | is-not-empty) {
      print -e $result.stderr
    }
    cleanup-temp-dir $tmp_dir
    exit 1
  }

  if $dry_run {
    open $output_file | ignore
  }

  cleanup-temp-dir $tmp_dir
}
