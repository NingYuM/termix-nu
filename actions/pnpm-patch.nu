#!/usr/bin/env nu

# Offline pnpm patch tool - Create pnpm patches without network access
# Usage: nu pnpm-patch.nu <package@version>
# Example: nu pnpm-patch.nu @alife/stage-supplier-selector@2.5.0
#
# This tool creates patches compatible with pnpm's patch format and automatically
# updates the patch hash in pnpm-lock.yaml to enable fully offline patching.
#
# External dependencies: git, patch
# No other dependencies - this script is self-contained and can run standalone.

# ============================================
# Color helpers for consistent output
# ============================================

def err [msg: string] { print -e $"(ansi r)($msg)(ansi reset)" }
def warn [msg: string] { print $"(ansi y)($msg)(ansi reset)" }
def info [msg: string] { print $"(ansi c)($msg)(ansi reset)" }
def success [msg: string] { print $"(ansi g)($msg)(ansi reset)" }
def separator [] { success "============================================" }

# ============================================
# Pure utility functions (exported for testing)
# ============================================

# Normalize input: accept argument or pipeline, normalize line endings
def normalize-input [content?: string]: nothing -> string {
  let input = if ($content != null) { $content } else if ($in | describe) == "string" { $in } else { "" }
  if ($input | is-empty) { "" } else { $input | str replace -a "\r\n" "\n" }
}

# Calculate the base32 hash of a string using MD5 (pnpm 9.x compatible)
export def hash-md5 [content?: string] {
  let input = normalize-input $content
  if ($input | is-empty) { return "" }
  $input | hash md5 --binary | encode base32 --nopad | str downcase
}

# Calculate the hex hash of a string using SHA256 (pnpm 10.x compatible)
export def hash-sha256 [content?: string] {
  let input = normalize-input $content
  if ($input | is-empty) { return "" }
  $input | hash sha256 --binary | encode hex | str downcase
}

# Detect pnpm major version for hash algorithm selection
# Returns major version number (9 or 10)
# Priority: 1) pnpm CLI version, 2) lockfile version string
# Use --skip-cli flag to skip CLI detection (for testing)
export def detect-lockfile-version [lock_content: string, --skip-cli]: nothing -> int {
  # First, try to detect from pnpm CLI version (most reliable)
  if not $skip_cli {
    let pnpm_version = try { ^pnpm --version | str trim } catch { "" }
    if ($pnpm_version | is-not-empty) {
      let major = $pnpm_version | split row '.' | first | into int
      if $major >= 10 { return 10 }
      if $major >= 9 { return 9 }
    }
  }

  # Fallback: check lockfile version string
  let version_line = $lock_content | lines | first
  match [($version_line has "'10"), ($version_line has "\"10")] {
    [true, _] | [_, true] => 10
    _ => 9
  }
}

# Calculate the patch hash based on pnpm version
# pnpm 9.x uses MD5, pnpm 10.x uses SHA256
export def calculate-patch-hash [patch_file: string, pnpm_version: int = 9]: nothing -> string {
  let content = open $patch_file --raw | decode utf-8
  match ($pnpm_version >= 10) {
    true => ($content | hash-sha256)
    false => ($content | hash-md5)
  }
}

# Parse package specification like @scope/name@version or name@version
# Also supports packages without version (e.g., @alife/link-to)
export def parse-package-spec [spec: string]: nothing -> record<name: string, version: string> {
  let spec = $spec | str trim
  if ($spec | is-empty) {
    return { name: "", version: "" }
  }

  let is_scoped = $spec starts-with '@'
  let parts = $spec | split row '@'

  match [$is_scoped, ($parts | length)] {
    [true, 3] => { name: $"@($parts.1)", version: $parts.2 }
    [true, 2] => { name: $"@($parts.1)", version: "" }  # Scoped package without version
    [false, 2] => { name: $parts.0, version: $parts.1 }
    [false, 1] => { name: $parts.0, version: "" }  # Simple package without version
    _ => { name: "", version: "" }
  }
}

# Build patch filename from package name and version
# For scoped packages (@scope/name): @scope__name@version.patch
# For non-scoped packages (name): name@version.patch
export def build-patch-filename [pkg_name: string, pkg_version: string]: nothing -> string {
  let is_scoped = $pkg_name starts-with '@'
  let name_part = $pkg_name | str replace -a '/' '__' | str replace -a '@' ''
  let prefix = if $is_scoped { "@" } else { "" }
  let version_suffix = if ($pkg_version | is-empty) { "" } else { $"@($pkg_version)" }

  $"($prefix)($name_part)($version_suffix).patch"
}

# Build patch key for package.json and pnpm-lock.yaml
export def build-patch-key [pkg_name: string, pkg_version: string]: nothing -> string {
  match ($pkg_version | is-empty) {
    true => $pkg_name
    false => $"($pkg_name)@($pkg_version)"
  }
}

# Find package directory in node_modules/.pnpm
# Returns null if not found
export def find-package-dir [pnpm_dir: string, pkg_name: string, pkg_version: string]: nothing -> string {
  let pkg_name_plus = $pkg_name | str replace '/' '+'
  let search_prefix = match ($pkg_version | is-empty) {
    true => $"($pkg_name_plus)@"
    false => $"($pkg_name_plus)@($pkg_version)"
  }

  ls $pnpm_dir
    | where type == dir
    | where { ($in.name | path basename) starts-with $search_prefix }
    | get name
    | first
}

# Generate patch using git diff
export def generate-patch [tmp_dir: string, basename: string]: nothing -> string {
  let result = do {
    cd $tmp_dir
    GIT_CONFIG_NOSYSTEM=1 git diff --no-index --text --full-index $"original/($basename)" $"modified/($basename)"
  } | complete

  # Format paths: replace temp directory paths with standard a/ and b/ prefixes
  $result.stdout
    | str replace -a $"a/original/($basename)/" "a/"
    | str replace -a $"b/modified/($basename)/" "b/"
    | str replace -a $"original/($basename)/" "a/"
    | str replace -a $"modified/($basename)/" "b/"
}

# Merge patch configuration into package.json data (pure function)
# Returns the updated package.json record, or null if no update needed
export def merge-patch-config [pkg: record, patch_key: string, patch_value: string]: nothing -> record {
  let patched_deps = $pkg | get -o pnpm.patchedDependencies

  # Skip if already configured with same value
  if ($patched_deps | is-not-empty) {
    let existing = $patched_deps | get -o $patch_key
    if ($existing | is-not-empty) and ($existing == $patch_value) {
      return null
    }
  }

  # Build updated config
  let has_pnpm = ($pkg | get -o pnpm | is-not-empty)
  let has_patched_deps = ($patched_deps | is-not-empty)

  match [$has_pnpm, $has_patched_deps] {
    [false, _] => ($pkg | insert pnpm { patchedDependencies: { $patch_key: $patch_value } })
    [true, false] => ($pkg | insert pnpm.patchedDependencies { $patch_key: $patch_value })
    [true, true] => ($pkg | update pnpm.patchedDependencies { $patched_deps | upsert $patch_key $patch_value })
  }
}

# Update hash in lock file content (pure function)
# Returns: { updated: bool, content: string, old_hash: string, new_hash: string } or null if key not found
# Handles both quoted ('pkg@version':) and unquoted (pkg@version:) keys
export def update-lock-content [content: string, patch_key: string, new_hash: string]: nothing -> record {
  # Try quoted format first (for scoped packages or explicitly quoted non-scoped)
  let quoted_key_line = $"  '($patch_key)':\n    hash: "
  # Also try unquoted format (for non-scoped packages)
  let unquoted_key_line = $"  ($patch_key):\n    hash: "

  # Determine which format is used
  let key_line = match [($content has $quoted_key_line), ($content has $unquoted_key_line)] {
    [true, _] => $quoted_key_line
    [_, true] => $unquoted_key_line
    _ => { return null }
  }

  # Extract old hash
  let key_start = $content | str index-of $key_line
  let hash_start = $key_start + ($key_line | str length)
  let after_hash = $content | str substring $hash_start..
  let newline_pos = $after_hash | str index-of "\n"
  let old_hash = $after_hash | str substring ..<$newline_pos | str trim

  if $old_hash == $new_hash {
    return { updated: false, content: $content, old_hash: $old_hash, new_hash: $new_hash }
  }

  let new_content = $content | str replace $"($key_line)($old_hash)" $"($key_line)($new_hash)"
  { updated: true, content: $new_content, old_hash: $old_hash, new_hash: $new_hash }
}

# Insert a new patch entry into lock file content (pure function)
# Returns: { inserted: bool, content: string } or null if patchedDependencies section not found
export def insert-lock-entry [content: string, patch_key: string, new_hash: string, patch_path: string]: nothing -> record {
  let pd_marker = "patchedDependencies:\n"

  if not ($content has $pd_marker) {
    return null
  }

  # Build the new entry with proper YAML formatting
  let new_entry = $"  '($patch_key)':\n    hash: ($new_hash)\n    path: ($patch_path)\n"

  # Find the end of patchedDependencies section
  let pd_start = $content | str index-of $pd_marker
  let after_pd = $content | str substring ($pd_start + ($pd_marker | str length))..

  # Find insert position: end of indented block
  let lines = $after_pd | lines
  mut insert_offset = 0
  for line in $lines {
    if ($line | is-empty) or ($line starts-with " ") or ($line starts-with "\t") {
      $insert_offset = $insert_offset + ($line | str length) + 1
    } else {
      break
    }
  }

  # Insert the new entry
  let insert_pos = $pd_start + ($pd_marker | str length) + $insert_offset
  let before = $content | str substring ..<$insert_pos
  let after = $content | str substring $insert_pos..

  { inserted: true, content: $"($before)($new_entry)($after)" }
}

# Inject patch_hash suffix into all version references in lockfile (pure function)
# This updates both importers and snapshots sections
# pkg_name: e.g. "@alife/u-touch"
# pkg_version: e.g. "2.1.5"
# patch_hash: the new hash to inject
# old_hash: optional - the old hash to replace (for re-patching)
export def inject-patch-hash-to-versions [
  content: string,
  pkg_name: string,
  pkg_version: string,
  patch_hash: string,
  old_hash?: string
]: nothing -> record {
  # Build the patch_hash suffix: "(patch_hash=xxx)"
  let hash_suffix = ['(patch_hash=' $patch_hash ')'] | str join
  let pkg_name_plus = $pkg_name | str replace '/' '+'
  # Check if this is a scoped package (starts with @)
  let is_scoped = $pkg_name starts-with '@'
  let escaped_version = $pkg_version | str replace -a '.' '\.'

  mut updated_content = $content

  # Strategy: Only update entries that include this SPECIFIC package name
  # This avoids affecting other packages that happen to have the same version

  # Step 1: For re-patching - replace old hash with new hash globally
  # This is safe because hash values are unique per package
  if ($old_hash | is-not-empty) and ($old_hash != $patch_hash) {
    let old_suffix = ['(patch_hash=' $old_hash ')'] | str join
    $updated_content = ($updated_content | str replace -a $old_suffix $hash_suffix)
  }

  # Step 1b: If no old_hash provided, try to find and replace any existing patch_hash for this package
  # This handles the case where update-lock-content found the entry but old_hash wasn't captured
  if ($old_hash | is-empty) {
    # Remove any existing patch_hash for this specific package version before adding new one
    # Pattern 1: pkg@version(patch_hash=...) -> pkg@version (for snapshots)
    let existing_hash_pattern = ['(' $pkg_name '@' $escaped_version ')\(patch_hash=[a-f0-9]+\)'] | str join
    let existing_hash_replace = '${1}'
    $updated_content = ($updated_content | str replace -ar $existing_hash_pattern $existing_hash_replace)

    # Also handle + format for snapshots
    let existing_hash_pattern_plus = ['(' $pkg_name_plus '@' $escaped_version ')\(patch_hash=[a-f0-9]+\)'] | str join
    $updated_content = ($updated_content | str replace -ar $existing_hash_pattern_plus $existing_hash_replace)

    # Pattern 2: version: X.Y.Z(patch_hash=...) -> version: X.Y.Z (for importers)
    # This handles the case where version field has patch_hash but no package name prefix
    let importer_hash_pattern = ['(version: )(' $escaped_version ')\(patch_hash=[a-f0-9]+\)'] | str join
    let importer_hash_replace = '${1}${2}'
    $updated_content = ($updated_content | str replace -ar $importer_hash_pattern $importer_hash_replace)
  }

  # Step 2: For first-time patching - add hash to snapshot keys (package-specific only)
  # Handle scoped snapshot keys: "'@pkg/name@version(" -> "'@pkg/name@version(patch_hash=xxx)("
  let snapshot_pattern1 = ["'" $pkg_name '@' $pkg_version '('] | str join
  let snapshot_replace1 = ["'" $pkg_name '@' $pkg_version $hash_suffix '('] | str join
  $updated_content = ($updated_content | str replace -a $snapshot_pattern1 $snapshot_replace1)

  # Handle snapshot keys with + format: "@pkg+name@version("
  let snapshot_pattern2 = [$pkg_name_plus '@' $pkg_version '('] | str join
  let snapshot_replace2 = [$pkg_name_plus '@' $pkg_version $hash_suffix '('] | str join
  $updated_content = ($updated_content | str replace -a $snapshot_pattern2 $snapshot_replace2)

  # Step 2b: Handle non-scoped packages in snapshots without peer deps
  # Only match entries in snapshots section (followed by {} or empty, NOT resolution:)
  # Pattern: "  pkg@version: {}" or "  pkg@version:\n    dependencies:"
  if not $is_scoped {
    # Match snapshot entry followed by " {}" (empty deps)
    let nonscoped_snapshot_pattern1 = ['(?m)(^  )(' $pkg_name '@' $escaped_version ')(: \{\})'] | str join
    let nonscoped_snapshot_replace1 = ['${1}${2}' $hash_suffix '${3}'] | str join
    $updated_content = ($updated_content | str replace -ar $nonscoped_snapshot_pattern1 $nonscoped_snapshot_replace1)

    # Match snapshot entry followed by ":\n    dependencies:" (has deps, not resolution)
    let nonscoped_snapshot_pattern2 = ['(?m)(^  )(' $pkg_name '@' $escaped_version ')(:\n    dependencies:)'] | str join
    let nonscoped_snapshot_replace2 = ['${1}${2}' $hash_suffix '${3}'] | str join
    $updated_content = ($updated_content | str replace -ar $nonscoped_snapshot_pattern2 $nonscoped_snapshot_replace2)
  }

  # Step 2c: Handle packages referenced as peer dependencies in other snapshot keys
  # Pattern: "(pkg@version)" -> "(pkg@version(patch_hash=xxx))"
  # This covers cases like "@ali/deep-form@...(lodash@4.17.21)(moment@...)"
  let peer_dep_pattern = ['(\()(' $pkg_name '@' $escaped_version ')(\))'] | str join
  let peer_dep_replace = ['${1}${2}' $hash_suffix '${3}'] | str join
  $updated_content = ($updated_content | str replace -ar $peer_dep_pattern $peer_dep_replace)

  # Step 2d: Handle packages in dependencies sections
  # Pattern: "pkg: version" -> "pkg: version(patch_hash=xxx)"
  # This covers entries like "lodash: 4.17.21" in dependencies of other packages
  let dep_value_pattern = ['(?m)(      ' $pkg_name ': )(' $escaped_version ')$'] | str join
  let dep_value_replace = ['${1}${2}' $hash_suffix] | str join
  $updated_content = ($updated_content | str replace -ar $dep_value_pattern $dep_value_replace)

  # Step 3: For first-time patching - add hash to importer version fields (package-specific)
  # Use multiline regex to match package name on preceding line, then update version field
  # Pattern matches: "'@pkg/name':\n        specifier: ...\n        version: X.Y.Z("
  # and replaces version field with: "version: X.Y.Z(patch_hash=xxx)("

  if $is_scoped {
    # Scoped packages have quotes around the name
    let importer_pattern = ["(?m)('" $pkg_name "':\n\\s+specifier:[^\n]+\n\\s+version: )(" $escaped_version ")(\\()"] | str join
    let importer_replace = ['${1}${2}' $hash_suffix '${3}'] | str join
    $updated_content = ($updated_content | str replace -ar $importer_pattern $importer_replace)
  } else {
    # Non-scoped packages don't have quotes - handle with parenthesis
    let importer_pattern = ["(?m)(" $pkg_name ":\n\\s+specifier:[^\n]+\n\\s+version: )(" $escaped_version ")(\\()"] | str join
    let importer_replace = ['${1}${2}' $hash_suffix '${3}'] | str join
    $updated_content = ($updated_content | str replace -ar $importer_pattern $importer_replace)

    # Non-scoped packages without parenthesis (version at end of line)
    let importer_pattern_eol = ["(?m)(" $pkg_name ":\n\\s+specifier:[^\n]+\n\\s+version: )(" $escaped_version ")$"] | str join
    let importer_replace_eol = ['${1}${2}' $hash_suffix] | str join
    $updated_content = ($updated_content | str replace -ar $importer_pattern_eol $importer_replace_eol)
  }

  # Handle double patch_hash (if we accidentally added it twice)
  let double_hash = [$hash_suffix $hash_suffix] | str join
  $updated_content = ($updated_content | str replace -a $double_hash $hash_suffix)

  { updated: ($updated_content != $content), content: $updated_content }
}

# Convert integrity hash (sha512-base64) to pnpm store hex path
# Returns: { bucket: "xx", hash: "remaining_hash" } or null if invalid
export def integrity-to-store-path [integrity: string]: nothing -> record {
  if ($integrity | is-empty) or ($integrity not-starts-with "sha512-") {
    return null
  }

  let base64_part = $integrity | str replace "sha512-" ""

  # Decode base64 to binary, then encode as hex
  let hex = try {
    $base64_part | decode base64 | encode hex | str downcase
  } catch {
    return null
  }

  if ($hex | str length) < 4 {
    return null
  }

  {
    bucket: ($hex | str substring 0..<2)
    hash: ($hex | str substring 2..)
  }
}

# Get package integrity from lockfile content
# Returns the integrity hash string or empty string if not found
export def get-package-integrity [lock_content: string, pkg_name: string, pkg_version: string]: nothing -> string {
  # Find the package entry and extract integrity from the next resolution line
  # Package entries can be either:
  #   '@scope/name@version':    (with quotes)
  #   name@version:             (without quotes)
  # Note: There may be multiple entries with the same name (e.g., in patchedDependencies and packages sections)
  # We need to find the one with resolution/integrity
  let pkg_marker_quoted = $"'($pkg_name)@($pkg_version)':"
  let pkg_marker_plain = $"($pkg_name)@($pkg_version):"
  let lines = $lock_content | lines

  mut found_pkg = false
  mut search_depth = 0
  for line in $lines {
    if $found_pkg {
      $search_depth = $search_depth + 1
      # Look for resolution line with integrity
      if ($line has "resolution:") and ($line has "integrity:") {
        # Extract the integrity hash using parse
        let match = $line | parse -r 'integrity:\s*(sha512-[A-Za-z0-9+/=]+)' | first
        if ($match | is-not-empty) {
          return $match.capture0
        }
      }
      # If we hit a non-indented line (next package) without finding resolution,
      # reset and continue searching for another matching entry
      if ($line not-starts-with " ") and ($line | is-not-empty) {
        $found_pkg = false
        $search_depth = 0
        # Check if this line itself is a matching entry
        let trimmed = $line | str trim
        if ($trimmed == $pkg_marker_quoted) or ($trimmed == $pkg_marker_plain) {
          $found_pkg = true
        }
        continue
      }
      # Limit search depth within an entry to avoid infinite loops
      if $search_depth > 20 {
        $found_pkg = false
        $search_depth = 0
      }
    } else {
      let trimmed = $line | str trim
      if ($trimmed == $pkg_marker_quoted) or ($trimmed == $pkg_marker_plain) {
        $found_pkg = true
        $search_depth = 0
      }
    }
  }

  ""
}

# Restore package from pnpm store to target directory
# Returns true on success, false on failure
export def restore-from-store [
  store_path: string
  integrity: string
  target_dir: string
]: nothing -> bool {
  let store_info = integrity-to-store-path $integrity
  if ($store_info == null) {
    return false
  }

  # Find the index.json file in store
  let index_file = [$store_path, "files", $store_info.bucket, $"($store_info.hash)-index.json"] | path join

  if not ($index_file | path exists) {
    return false
  }

  # Parse index.json to get file list
  let index_data = try {
    open $index_file
  } catch {
    return false
  }

  let files = $index_data | get -o files
  if ($files | is-empty) {
    return false
  }

  # Create target directory
  mkdir $target_dir

  # Copy each file from store to target
  for entry in ($files | transpose name meta) {
    let file_name = $entry.name
    let file_meta = $entry.meta
    let file_integrity = $file_meta | get -o integrity
    let file_mode = $file_meta | get -o mode

    if ($file_integrity | is-empty) {
      continue
    }

    let file_store_info = integrity-to-store-path $file_integrity
    if ($file_store_info == null) {
      continue
    }

    let src_file = [$store_path, "files", $file_store_info.bucket, $file_store_info.hash] | path join
    let src_file_exec = $"($src_file)-exec"
    let dst_file = [$target_dir, $file_name] | path join

    # pnpm store uses -exec suffix for executable files (mode 0755)
    # Try both regular and -exec versions
    let actual_src = if ($src_file | path exists) {
      $src_file
    } else if ($src_file_exec | path exists) {
      $src_file_exec
    } else {
      continue
    }

    # Create parent directories if needed
    let parent_dir = $dst_file | path dirname
    if not ($parent_dir | path exists) {
      mkdir $parent_dir
    }

    cp $actual_src $dst_file

    # Set file permissions if mode is specified
    # mode 493 = 0755 (executable), mode 420 = 0644 (non-executable)
    if ($file_mode | is-not-empty) and ($file_mode == 493) {
      chmod 755 $dst_file
    }
  }

  true
}

# ============================================
# Side-effect functions (file operations)
# ============================================

# Check if required tools are installed
def check-dependencies [] {
  for tool in [git patch] {
    if (which $tool | first) == null {
      err $"Error: ($tool) is not installed. Please install ($tool) first."
      exit 1
    }
  }
  print $'Current node version: (ansi g)(node --version)(ansi rst)'
  print $'Current pnpm version: (ansi g)(pnpm --version)(ansi rst)'
}

# Revert a patch to get the original unpatched version
# Returns true on success, false on failure
export def revert-patch [pkg_dir: string, patch_file: string]: nothing -> bool {
  warn "Found existing patch, reverting to get original version..."

  # Ensure absolute paths for use inside cd block
  let abs_patch_file = match ($patch_file | path type) {
    "absolute" => $patch_file
    _ => ([(pwd), $patch_file] | path join)
  }

  # Use patch command instead of git apply, as git apply sometimes skips patches
  # that it considers already applied (even when they're not)
  let result = do {
    cd $pkg_dir
    ^patch -R -p1 --no-backup-if-mismatch -i $abs_patch_file
  } | complete

  match $result.exit_code {
    0 => {
      success "Successfully reverted to original version"
      true
    }
    _ => {
      # Try with force option
      let result2 = do {
        cd $pkg_dir
        ^patch -R -p1 --no-backup-if-mismatch -f -i $abs_patch_file
      } | complete

      if $result2.exit_code == 0 {
        success "Reverted with some warnings"
        true
      } else {
        err "Error: Could not revert patch. The installed package may not match the patch."
        err "This can happen if the patch was created for a different version of the package."
        err $"Details: ($result.stderr)"
        false
      }
    }
  }
}

# Update package.json with patch configuration
def update-package-json [path: string, patch_key: string, patch_value: string] {
  if not ($path | path exists) {
    warn "Warning: package.json not found"
    return
  }

  let pkg = open $path
  let updated = merge-patch-config $pkg $patch_key $patch_value

  if ($updated == null) {
    success "Patch already configured in package.json"
    return
  }

  info "Updating package.json..."
  $updated | save -f $path
  success "Added patch configuration to package.json"
}

# Update the patch hash in pnpm-lock.yaml
# Also injects patch_hash into all version references in importers and snapshots
def update-lock-hash [
  lock_file: string,
  patch_key: string,
  new_hash: string,
  patch_path: string,
  pkg_name: string,
  pkg_version: string
] {
  if not ($lock_file | path exists) {
    warn "Warning: pnpm-lock.yaml not found, skipping hash update"
    return
  }

  info "Updating hash in pnpm-lock.yaml..."

  let content = open $lock_file --raw | decode utf-8

  # Try to update existing entry first
  let update_result = update-lock-content $content $patch_key $new_hash

  mut final_content = $content
  mut old_hash_value = ""

  if ($update_result != null) {
    if not $update_result.updated {
      success $"Hash unchanged: ($new_hash)"
    } else {
      $final_content = $update_result.content
      $old_hash_value = $update_result.old_hash
      success $"Updated hash: ($update_result.old_hash) -> ($new_hash)"
    }
  } else {
    # Entry doesn't exist, try to insert new one
    let insert_result = insert-lock-entry $content $patch_key $new_hash $patch_path

    if ($insert_result == null) {
      warn "Warning: patchedDependencies section not found in pnpm-lock.yaml"
      warn "You may need to run 'pnpm install' first to initialize the lock file"
      return
    }

    $final_content = $insert_result.content
    success $"Added new patch entry: ($patch_key)"
  }

  # Inject patch_hash into version references (for offline patching support)
  if ($pkg_version | is-not-empty) {
    let inject_result = inject-patch-hash-to-versions $final_content $pkg_name $pkg_version $new_hash $old_hash_value
    if $inject_result.updated {
      $final_content = $inject_result.content
      success "Injected patch_hash into version references"
    }
  }

  $final_content | save -f $lock_file
}

# Copy all contents from source directory to destination
def copy-dir-contents [src: string, dst: string] {
  mkdir $dst
  glob ($src)/* | each { cp -r $in $dst }
}

# Cleanup temporary directory
def cleanup [tmp_dir: string] {
  if ($tmp_dir | path exists) { rm -rf $tmp_dir }
}

# ============================================
# Main entry point
# ============================================

# Create pnpm patch for a specified package in offline mode
@example '为 scoped package 创建 patch' {
  t pnpm-patch @alife/stage-supplier-selector@2.5.0
} --result '在 patches/ 目录创建 @alife__stage-supplier-selector@2.5.0.patch 并更新 `pnpm-lock.yaml`'
@example '为普通 package 创建 patch' {
  t pnpm-patch lodash@4.17.21
} --result '在 patches/ 目录创建 lodash@4.17.21.patch 并更新 `pnpm-lock.yaml`'
@example '指定项目根目录创建 patch' {
  t pnpm-patch moment@2.30.1 -p /path/to/project
} --result '在指定项目的 patches/ 目录创建 patch 文件'
@example '为已有 patch 的包添加新修改（累积模式）' {
  t pnpm-patch @ali/u-touch@2.1.5
} --result '基于现有 patch 累积新的修改，生成包含所有变更的新 patch'
def main [
  package_spec: string  # Package specification: @scope/name@version or name@version
  --project-root (-p): string  # Project root directory (default: current directory)
] {
  # Check dependencies
  check-dependencies

  # Setup paths
  let project_root = match ($project_root | is-not-empty) {
    true => $project_root
    false => (pwd)
  }
  let patches_dir = [$project_root, "patches"] | path join
  let tmp_dir = [$project_root, ".pnpm-patch-tmp"] | path join
  let pnpm_dir = [$project_root, "node_modules", ".pnpm"] | path join

  # Parse and validate package spec
  let pkg = parse-package-spec $package_spec

  if ($pkg.name | is-empty) {
    err "Error: Invalid package specification. Use format: @scope/name@version or name@version"
    exit 1
  }

  info $"Package: ($pkg.name)"
  if ($pkg.version | is-not-empty) {
    info $"Version: ($pkg.version)"
  } else {
    warn "Warning: No version specified, will match any version"
  }

  # Validate pnpm directory exists
  if not ($pnpm_dir | path exists) {
    err "Error: node_modules/.pnpm not found. Run pnpm install first."
    exit 1
  }

  # Find package in node_modules/.pnpm
  let pkg_pnpm_dir = find-package-dir $pnpm_dir $pkg.name $pkg.version

  if ($pkg_pnpm_dir == null) {
    err $"Error: Package ($pkg.name)@($pkg.version) not found in node_modules/.pnpm"
    exit 1
  }

  let pkg_source_dir = [$pkg_pnpm_dir, "node_modules", $pkg.name] | path join

  if not ($pkg_source_dir | path exists) {
    err $"Error: Package directory not found at ($pkg_source_dir)"
    exit 1
  }

  info $"Found package at: ($pkg_source_dir)"

  # Setup patch paths
  let basename = $pkg.name | path basename
  let patch_filename = build-patch-filename $pkg.name $pkg.version
  let patch_file = [$patches_dir, $patch_filename] | path join
  let patch_key = build-patch-key $pkg.name $pkg.version
  let original_dir = [$tmp_dir, "original", $basename] | path join
  let modified_dir = [$tmp_dir, "modified", $basename] | path join

  # Prepare temp directories
  cleanup $tmp_dir
  mkdir ([$tmp_dir, "original"] | path join) ([$tmp_dir, "modified"] | path join)

  let has_existing_patch = ($patch_file | path exists)

  # Always try to restore original from pnpm store first (most reliable source)
  # Fall back to node_modules copy if store is not available
  mut got_original_from_store = false

  if ($pkg.version | is-not-empty) {
    let lock_file_path = [$project_root, "pnpm-lock.yaml"] | path join
    if ($lock_file_path | path exists) {
      let lock_content = open $lock_file_path --raw | decode utf-8
      let pkg_integrity = get-package-integrity $lock_content $pkg.name $pkg.version

      if ($pkg_integrity | is-not-empty) {
        let store_path = try { ^pnpm store path | str trim } catch { "" }

        if ($store_path | is-not-empty) and ($store_path | path exists) {
          info "Trying to restore original from pnpm store..."
          let store_success = restore-from-store $store_path $pkg_integrity $original_dir

          if $store_success {
            success "Successfully restored original from pnpm store"
            $got_original_from_store = true
          } else {
            warn "Could not restore from store, falling back to node_modules copy..."
          }
        }
      }
    }
  }

  # Fallback: Copy from node_modules if store restore failed
  if not $got_original_from_store {
    info "Copying original from node_modules..."
    copy-dir-contents $pkg_source_dir $original_dir
  }

  # For modified directory:
  # - If existing patch: copy from node_modules (which has patch applied)
  # - If no existing patch: copy from original (both start the same)
  if $has_existing_patch {
    info "Copying patched version to modified directory..."
    copy-dir-contents $pkg_source_dir $modified_dir
  } else {
    copy-dir-contents $original_dir $modified_dir
  }

  # For cumulative mode with existing patch, if we couldn't get original from store,
  # we need to revert the patch to get the true original
  if $has_existing_patch and (not $got_original_from_store) {
    let revert_success = revert-patch $original_dir $patch_file
    if not $revert_success {
      err "Cannot create cumulative patch: failed to revert existing patch."
      err "Please ensure the installed package matches the existing patch version."
      cleanup $tmp_dir
      exit 1
    }
  }

  if $has_existing_patch {
    info "Cumulative mode: original restored, existing patch preserved in modified/"
  }

  # Prompt user to edit
  separator
  success "Ready for editing!"
  separator
  info "\nEdit the files in:"
  print $"  ($modified_dir)\n"
  info "Original (unpatched) version is at:"
  print $"  ($original_dir)\n"
  if $has_existing_patch {
    warn "Note: The modified directory contains the existing patch changes."
    warn "      Your new changes will be ADDED to the existing patch (cumulative).\n"
  }
  warn "Press Enter when you have finished editing, or press Esc to cancel..."

  let key_event = input listen --types [key]
  if $key_event.code == "escape" {
    warn "\nPatch creation cancelled."
    cleanup $tmp_dir
    exit 0
  }

  # Generate patch
  info "Generating patch..."
  mkdir $patches_dir
  let patch_content = generate-patch $tmp_dir $basename

  if ($patch_content | is-empty) {
    warn "No changes detected. No patch file created."
    cleanup $tmp_dir
    exit 0
  }

  $patch_content | save -f $patch_file
  success $"Patch saved to: ($patch_file)"

  # Detect pnpm version from lockfile and calculate hash
  let lock_file = [$project_root, "pnpm-lock.yaml"] | path join
  let lock_content = match ($lock_file | path exists) {
    true => (open $lock_file --raw | decode utf-8)
    false => ""
  }
  let pnpm_version = detect-lockfile-version $lock_content
  info $"Detected pnpm lockfile version: ($pnpm_version)"

  let patch_hash = calculate-patch-hash $patch_file $pnpm_version
  info $"Patch hash: ($patch_hash)"

  # Update configurations
  let package_json = [$project_root, "package.json"] | path join
  let patch_rel_path = $"patches/($patch_filename)"

  update-package-json $package_json $patch_key $patch_rel_path
  update-lock-hash $lock_file $patch_key $patch_hash $patch_rel_path $pkg.name $pkg.version

  # Cleanup
  cleanup $tmp_dir

  # Show next steps
  separator
  success "Done!"
  separator
  info "\nNext steps:"
  print "  1. The patch hash has been updated in pnpm-lock.yaml"
  print "  2. Run 'pnpm install --offline' to apply the patch offline"
  print "  3. Verify the changes work as expected\n"
}
