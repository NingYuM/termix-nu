#!/usr/bin/env nu
# Description:
#   Unit tests for pnpm-patch.nu
# Usage:
#   nu tools/tests/test-pnpm-patch.nu
# Or with custom project root:
#   PROJECT_ROOT=/path/to/project nu tools/tests/test-pnpm-patch.nu

use std assert
use ../pnpm-patch.nu [
  hash-md5
  hash-sha256
  detect-lockfile-version
  parse-package-spec
  build-patch-filename
  build-patch-key
  find-package-dir
  calculate-patch-hash
  generate-patch
  merge-patch-config
  update-lock-content
  insert-lock-entry
  inject-patch-hash-to-versions
  revert-patch
  integrity-to-store-path
  get-package-integrity
  restore-from-store
]

# Get project root from environment variable or use current directory
def get-project-root []: nothing -> string {
  match ($env.PROJECT_ROOT? | default "") {
    "" => (pwd)
    $root => $root
  }
}

def main [] {
  $env.config.table.mode = 'psql'

  # Determine project root
  let project_root = get-project-root
  $env.FIXTURES_DIR = $"($project_root)/tools/tests/fixtures"

  # Ensure project root is valid
  let lock_file = $"($project_root)/pnpm-lock.yaml"
  if not ($lock_file | path exists) {
    print $"Error: pnpm-lock.yaml not found in ($project_root)"
    print "Please run this test from the project root directory or set PROJECT_ROOT environment variable"
    exit 1
  }

  print $"Project root: ($project_root)"
  print $"Fixtures dir: ($env.FIXTURES_DIR)"

  # Setup fixtures before running tests
  setup-fixtures

  # Collect and run all tests
  let tests = [
    { name: "hash-md5 normalizes line endings", execute: { test-hash-md5-normalize } }
    { name: "hash-md5 is deterministic", execute: { test-hash-md5-deterministic } }
    { name: "hash-md5 produces lowercase base32", execute: { test-hash-md5-format } }
    { name: "hash-sha256 normalizes line endings", execute: { test-hash-sha256-normalize } }
    { name: "hash-sha256 produces longer hash than md5", execute: { test-hash-sha256-length } }
    { name: "detect-lockfile-version detects pnpm 9", execute: { test-detect-version-9 } }
    { name: "detect-lockfile-version detects pnpm 10", execute: { test-detect-version-10 } }
    { name: "calculate-patch-hash uses md5 for pnpm 9", execute: { test-patch-hash-pnpm9 } }
    { name: "calculate-patch-hash uses sha256 for pnpm 10", execute: { test-patch-hash-pnpm10 } }
    { name: "parse-package-spec with simple package", execute: { test-parse-simple } }
    { name: "parse-package-spec with scoped package", execute: { test-parse-scoped } }
    { name: "parse-package-spec with complex scoped package", execute: { test-parse-complex-scoped } }
    { name: "parse-package-spec with prerelease version", execute: { test-parse-prerelease } }
    { name: "parse-package-spec with simple package no version", execute: { test-parse-simple-no-version } }
    { name: "parse-package-spec with invalid input empty string", execute: { test-parse-invalid-empty } }
    { name: "parse-package-spec with invalid input only at sign", execute: { test-parse-invalid-at } }
    { name: "parse-package-spec with scoped package no version", execute: { test-parse-scoped-no-version } }
    { name: "build-patch-filename with scoped package", execute: { test-build-filename-scoped } }
    { name: "build-patch-filename without version", execute: { test-build-filename-no-version } }
    { name: "build-patch-filename with non-scoped package", execute: { test-build-filename-non-scoped } }
    { name: "build-patch-filename non-scoped without version", execute: { test-build-filename-non-scoped-no-version } }
    { name: "build-patch-key with version", execute: { test-build-key-with-version } }
    { name: "build-patch-key without version", execute: { test-build-key-no-version } }
    { name: "find-package-dir with simple package", execute: { test-find-simple } }
    { name: "find-package-dir with scoped package", execute: { test-find-scoped } }
    { name: "find-package-dir with hash suffix", execute: { test-find-hash-suffix } }
    { name: "find-package-dir with no version", execute: { test-find-no-version } }
    { name: "find-package-dir returns null when not found", execute: { test-find-not-found } }
    { name: "generate-patch creates valid diff", execute: { test-generate-valid-diff } }
    { name: "generate-patch formats paths correctly", execute: { test-generate-path-format } }
    { name: "merge-patch-config adds pnpm section to empty package", execute: { test-merge-empty } }
    { name: "merge-patch-config adds patchedDependencies to existing pnpm", execute: { test-merge-existing-pnpm } }
    { name: "merge-patch-config adds to existing patchedDependencies", execute: { test-merge-existing-patches } }
    { name: "merge-patch-config returns null if already configured", execute: { test-merge-already-configured } }
    { name: "update-lock-content updates hash", execute: { test-lock-update } }
    { name: "update-lock-content returns not updated when hash same", execute: { test-lock-same-hash } }
    { name: "update-lock-content returns null when key not found", execute: { test-lock-not-found } }
    { name: "update-lock-content handles scoped packages", execute: { test-lock-scoped } }
    { name: "update-lock-content handles unquoted non-scoped packages", execute: { test-lock-unquoted-nonscoped } }
    { name: "update-lock-content preserves other content", execute: { test-lock-preserve } }
    { name: "insert-lock-entry inserts new entry", execute: { test-insert-new-entry } }
    { name: "insert-lock-entry handles scoped packages", execute: { test-insert-scoped } }
    { name: "insert-lock-entry returns null without patchedDependencies", execute: { test-insert-no-section } }
    { name: "insert-lock-entry preserves existing entries", execute: { test-insert-preserve-existing } }
    { name: "inject-patch-hash adds hash to importer versions", execute: { test-inject-hash-importers } }
    { name: "inject-patch-hash adds hash to snapshot keys", execute: { test-inject-hash-snapshots } }
    { name: "inject-patch-hash handles plus format in snapshots", execute: { test-inject-hash-plus-format } }
    { name: "inject-patch-hash deduplicates double hashes", execute: { test-inject-hash-dedup } }
    { name: "inject-patch-hash returns updated false when no changes", execute: { test-inject-hash-no-change } }
    { name: "inject-patch-hash replaces old hash with new hash", execute: { test-inject-hash-replace-old } }
    { name: "inject-patch-hash replaces existing hash without old_hash param", execute: { test-inject-hash-replace-existing-without-old-hash } }
    { name: "inject-patch-hash handles non-scoped package snapshots", execute: { test-inject-hash-nonscoped-snapshots } }
    { name: "inject-patch-hash handles non-scoped package importers", execute: { test-inject-hash-nonscoped-importers } }
    { name: "revert-patch reverts patched file to original", execute: { test-revert-patch-success } }
    { name: "revert-patch fails on mismatched content", execute: { test-revert-patch-failure } }
    { name: "cumulative mode generates patch with old and new changes", execute: { test-cumulative-patch-generation } }
    { name: "integrity-to-store-path converts sha512 correctly", execute: { test-integrity-to-store-path } }
    { name: "integrity-to-store-path returns null for invalid input", execute: { test-integrity-to-store-path-invalid } }
    { name: "get-package-integrity extracts integrity from lockfile", execute: { test-get-package-integrity } }
    { name: "get-package-integrity handles quoted scoped packages", execute: { test-get-package-integrity-quoted } }
    { name: "get-package-integrity skips patchedDependencies section", execute: { test-get-package-integrity-skip-patched } }
    { name: "restore-from-store restores package from mock store", execute: { test-restore-from-store } }
  ]

  let results = $tests | each { |test| run_test $test }

  # Cleanup fixtures after tests
  cleanup-fixtures

  print -n (char nl)
  print_results $results
  print_summary $results

  if ($results | any { |test| $test.result == "FAIL" }) {
    exit 1
  }
}

# ============================================
# Test Runner Utilities
# ============================================

def print_results [results: list<record<name: string, result: string>>] {
  let display_table = $results | update result { |row|
    let emoji = if ($row.result == "PASS") { $"(ansi g)√(ansi rst)" } else { $"(ansi r)×(ansi rst)" }
    $"($emoji) ($row.result)"
  }

  if ("GITHUB_ACTIONS" in $env) {
    print ($display_table | to md --pretty)
  } else {
    print $display_table
  }

  # Print error details for failed tests
  let failed = $results | where result == "FAIL"
  for test in $failed {
    print $"\n($test.name): ($test.error)"
  }
}

def print_summary [results: list<record<name: string, result: string>>]: nothing -> bool {
  let success = $results | where ($it.result == "PASS") | length
  let failure = $results | where ($it.result == "FAIL") | length
  let count = $results | length

  if ($failure == 0) {
    print $"\n(ansi g)Testing completed: ($success) of ($count) were successful(ansi reset)"
  } else {
    print $"\n(ansi r)Testing completed: ($failure) of ($count) failed(ansi reset)"
  }
}

def run_test [test: record<name: string, execute: closure>]: nothing -> record<name: string, result: string, error: string> {
  try {
    do ($test.execute)
    { result: "PASS", name: $test.name, error: "" }
  } catch { |error|
    { result: "FAIL", name: $test.name, error: $"($error.msg)" }
  }
}

# ============================================
# Test Fixtures Setup/Cleanup
# ============================================

def setup-fixtures [] {
  # Create fixtures directory
  mkdir $env.FIXTURES_DIR

  # Create mock pnpm directory structure
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  mkdir $"($pnpm_dir)/lodash@4.17.21/node_modules/lodash"
  mkdir $"($pnpm_dir)/@babel+core@7.20.0/node_modules/@babel/core"
  mkdir $"($pnpm_dir)/@alife+utils@1.0.0_hash123/node_modules/@alife/utils"

  # Create sample files in mock packages
  "module.exports = {}" | save $"($pnpm_dir)/lodash@4.17.21/node_modules/lodash/index.js"
  "module.exports = {}" | save $"($pnpm_dir)/@babel+core@7.20.0/node_modules/@babel/core/index.js"

  # Create test patch file
  let patch_content = "diff --git a/index.js b/index.js
index 1234567..abcdefg 100644
--- a/index.js
+++ b/index.js
@@ -1 +1 @@
-module.exports = {}
+module.exports = { patched: true }
"
  $patch_content | save $"($env.FIXTURES_DIR)/test.patch"

  # Create test package.json files
  { name: "test-project", version: "1.0.0" } | save $"($env.FIXTURES_DIR)/package-empty.json"
  { name: "test-project", version: "1.0.0", pnpm: { overrides: {} } } | save $"($env.FIXTURES_DIR)/package-with-pnpm.json"
  {
    name: "test-project",
    version: "1.0.0",
    pnpm: { patchedDependencies: { "other@1.0.0": "patches/other.patch" } }
  } | save $"($env.FIXTURES_DIR)/package-with-patches.json"

  # Create test pnpm-lock.yaml
  let lock_content = "lockfileVersion: '9.0'

patchedDependencies:
  'lodash@4.17.21':
    hash: oldhash123
  '@babel/core@7.20.0':
    hash: babeloldhash

packages:
  lodash@4.17.21:
    resolution: {integrity: sha512-xxx}
"
  $lock_content | save $"($env.FIXTURES_DIR)/pnpm-lock.yaml"

  # Create directories for generate-patch test
  mkdir $"($env.FIXTURES_DIR)/patch-test/original/mypackage"
  mkdir $"($env.FIXTURES_DIR)/patch-test/modified/mypackage"
  "const x = 1;" | save $"($env.FIXTURES_DIR)/patch-test/original/mypackage/index.js"
  "const x = 2;" | save $"($env.FIXTURES_DIR)/patch-test/modified/mypackage/index.js"
}

def cleanup-fixtures [] {
  rm -rf $env.FIXTURES_DIR
}

# ============================================
# Tests for parse-package-spec
# ============================================

def test-parse-simple [] {
  let result = parse-package-spec "lodash@4.17.21"
  assert equal $result.name "lodash"
  assert equal $result.version "4.17.21"
}

def test-parse-scoped [] {
  let result = parse-package-spec "@babel/core@7.20.0"
  assert equal $result.name "@babel/core"
  assert equal $result.version "7.20.0"
}

def test-parse-complex-scoped [] {
  let result = parse-package-spec "@alife/stage-supplier-selector@2.5.0"
  assert equal $result.name "@alife/stage-supplier-selector"
  assert equal $result.version "2.5.0"
}

def test-parse-prerelease [] {
  let result = parse-package-spec "react@18.0.0-alpha.1"
  assert equal $result.name "react"
  assert equal $result.version "18.0.0-alpha.1"
}

def test-parse-simple-no-version [] {
  let result = parse-package-spec "lodash"
  assert equal $result.name "lodash"
  assert equal $result.version ""
}

def test-parse-invalid-empty [] {
  let result = parse-package-spec ""
  assert equal $result.name ""
  assert equal $result.version ""
}

def test-parse-invalid-at [] {
  let result = parse-package-spec "@"
  assert equal $result.name "@"
  assert equal $result.version ""
}

def test-parse-scoped-no-version [] {
  let result = parse-package-spec "@babel/core"
  assert equal $result.name "@babel/core"
  assert equal $result.version ""
}

# ============================================
# Tests for build-patch-filename
# ============================================

def test-build-filename-scoped [] {
  let result = build-patch-filename "@alife/stage-supplier-selector" "2.5.0"
  assert equal $result "@alife__stage-supplier-selector@2.5.0.patch"
}

def test-build-filename-no-version [] {
  let result = build-patch-filename "@alife/link-to" ""
  assert equal $result "@alife__link-to.patch"
}

def test-build-filename-non-scoped [] {
  # Non-scoped packages should NOT have @ prefix
  let result = build-patch-filename "print-js" "1.6.0"
  assert equal $result "print-js@1.6.0.patch"
}

def test-build-filename-non-scoped-no-version [] {
  # Non-scoped packages without version
  let result = build-patch-filename "lodash" ""
  assert equal $result "lodash.patch"
}

# ============================================
# Tests for build-patch-key
# ============================================

def test-build-key-with-version [] {
  let result = build-patch-key "@alife/stage-supplier-selector" "2.5.0"
  assert equal $result "@alife/stage-supplier-selector@2.5.0"
}

def test-build-key-no-version [] {
  let result = build-patch-key "@alife/link-to" ""
  assert equal $result "@alife/link-to"
}

# ============================================
# Tests for find-package-dir
# ============================================

def test-find-simple [] {
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  let result = find-package-dir $pnpm_dir "lodash" "4.17.21"
  assert str contains $result "lodash@4.17.21"
}

def test-find-scoped [] {
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  let result = find-package-dir $pnpm_dir "@babel/core" "7.20.0"
  assert str contains $result "@babel+core@7.20.0"
}

def test-find-hash-suffix [] {
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  let result = find-package-dir $pnpm_dir "@alife/utils" "1.0.0"
  assert str contains $result "@alife+utils@1.0.0"
}

def test-find-no-version [] {
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  let result = find-package-dir $pnpm_dir "lodash" ""
  assert str contains $result "lodash@"
}

def test-find-not-found [] {
  let pnpm_dir = $"($env.FIXTURES_DIR)/node_modules/.pnpm"
  let result = find-package-dir $pnpm_dir "nonexistent" "1.0.0"
  assert equal $result null
}

# ============================================
# Tests for hash-md5 and hash-sha256
# ============================================

def test-hash-md5-normalize [] {
  let content_lf = "line1\nline2\n"
  let content_crlf = "line1\r\nline2\r\n"

  let hash_lf = $content_lf | hash-md5
  let hash_crlf = $content_crlf | hash-md5

  assert equal $hash_lf $hash_crlf
}

def test-hash-md5-deterministic [] {
  let content = "test content for hashing"
  let hash1 = $content | hash-md5
  let hash2 = $content | hash-md5

  assert equal $hash1 $hash2
}

def test-hash-md5-format [] {
  let content = "test content"
  let hash = $content | hash-md5

  # base32 lowercase characters are a-z and 2-7
  assert ($hash =~ '^[a-z2-7]+$')
  # MD5 hash in base32 should be 26 characters
  assert equal ($hash | str length) 26
}

def test-hash-sha256-normalize [] {
  let content_lf = "line1\nline2\n"
  let content_crlf = "line1\r\nline2\r\n"

  let hash_lf = $content_lf | hash-sha256
  let hash_crlf = $content_crlf | hash-sha256

  assert equal $hash_lf $hash_crlf
}

def test-hash-sha256-length [] {
  let content = "test content"
  let md5_hash = $content | hash-md5
  let sha256_hash = $content | hash-sha256

  # SHA256 produces longer hash than MD5
  assert (($sha256_hash | str length) > ($md5_hash | str length))
  # SHA256 in hex should be 64 characters (pnpm 10 format)
  assert equal ($sha256_hash | str length) 64
  # Should be lowercase hex characters
  assert ($sha256_hash =~ '^[a-f0-9]+$')
}

# ============================================
# Tests for detect-lockfile-version
# ============================================

def test-detect-version-9 [] {
  # Use --skip-cli to test lockfile content detection
  let content = "lockfileVersion: '9.0'\n\nsettings:\n  autoInstallPeers: true\n"
  let version = detect-lockfile-version $content --skip-cli
  assert equal $version 9
}

def test-detect-version-10 [] {
  # Use --skip-cli to test lockfile content detection
  let content = "lockfileVersion: '10.0'\n\nsettings:\n  autoInstallPeers: true\n"
  let version = detect-lockfile-version $content --skip-cli
  assert equal $version 10
}

# ============================================
# Tests for calculate-patch-hash
# ============================================

def test-patch-hash-pnpm9 [] {
  let patch_file = $"($env.FIXTURES_DIR)/test.patch"
  let hash = calculate-patch-hash $patch_file 9

  # pnpm 9 uses MD5, which produces 26 character base32 hash
  assert equal ($hash | str length) 26
  assert ($hash =~ '^[a-z2-7]+$')
}

def test-patch-hash-pnpm10 [] {
  let patch_file = $"($env.FIXTURES_DIR)/test.patch"
  let hash = calculate-patch-hash $patch_file 10

  # pnpm 10 uses SHA256, which produces 64 character hex hash
  assert equal ($hash | str length) 64
  assert ($hash =~ '^[a-f0-9]+$')
}

# ============================================
# Tests for generate-patch
# ============================================

def test-generate-valid-diff [] {
  let tmp_dir = $"($env.FIXTURES_DIR)/patch-test"
  let result = generate-patch $tmp_dir "mypackage"

  assert str contains $result "diff --git"
  assert str contains $result "a/index.js"
  assert str contains $result "b/index.js"
  assert str contains $result "-const x = 1;"
  assert str contains $result "+const x = 2;"
}

def test-generate-path-format [] {
  let tmp_dir = $"($env.FIXTURES_DIR)/patch-test"
  let result = generate-patch $tmp_dir "mypackage"

  # Should use a/ and b/ prefixes, not original/mypackage/ paths
  assert (not ($result | str contains "original/mypackage/"))
  assert (not ($result | str contains "modified/mypackage/"))
}

# ============================================
# Tests for merge-patch-config
# ============================================

def test-merge-empty [] {
  let pkg = { name: "test", version: "1.0.0" }
  let result = merge-patch-config $pkg "lodash@4.17.21" "patches/lodash.patch"

  assert equal $result.pnpm.patchedDependencies."lodash@4.17.21" "patches/lodash.patch"
}

def test-merge-existing-pnpm [] {
  let pkg = { name: "test", version: "1.0.0", pnpm: { overrides: {} } }
  let result = merge-patch-config $pkg "lodash@4.17.21" "patches/lodash.patch"

  assert equal $result.pnpm.patchedDependencies."lodash@4.17.21" "patches/lodash.patch"
  assert equal $result.pnpm.overrides {}
}

def test-merge-existing-patches [] {
  let pkg = {
    name: "test",
    version: "1.0.0",
    pnpm: { patchedDependencies: { "other@1.0.0": "patches/other.patch" } }
  }
  let result = merge-patch-config $pkg "lodash@4.17.21" "patches/lodash.patch"

  assert equal $result.pnpm.patchedDependencies."lodash@4.17.21" "patches/lodash.patch"
  assert equal $result.pnpm.patchedDependencies."other@1.0.0" "patches/other.patch"
}

def test-merge-already-configured [] {
  let pkg = {
    name: "test",
    version: "1.0.0",
    pnpm: { patchedDependencies: { "lodash@4.17.21": "patches/lodash.patch" } }
  }
  let result = merge-patch-config $pkg "lodash@4.17.21" "patches/lodash.patch"

  assert equal $result null
}

# ============================================
# Tests for update-lock-content
# ============================================

def test-lock-update [] {
  let content = "patchedDependencies:
  'lodash@4.17.21':
    hash: oldhash123
"
  let result = update-lock-content $content "lodash@4.17.21" "newhash456"

  assert equal $result.updated true
  assert equal $result.old_hash "oldhash123"
  assert equal $result.new_hash "newhash456"
  assert str contains $result.content "hash: newhash456"
}

def test-lock-same-hash [] {
  let content = "patchedDependencies:
  'lodash@4.17.21':
    hash: samehash
"
  let result = update-lock-content $content "lodash@4.17.21" "samehash"

  assert equal $result.updated false
  assert equal $result.old_hash "samehash"
}

def test-lock-not-found [] {
  let content = "patchedDependencies:
  'other@1.0.0':
    hash: somehash
"
  let result = update-lock-content $content "lodash@4.17.21" "newhash"

  assert equal $result null
}

def test-lock-scoped [] {
  let content = "patchedDependencies:
  '@babel/core@7.20.0':
    hash: babelold
"
  let result = update-lock-content $content "@babel/core@7.20.0" "babelnew"

  assert equal $result.updated true
  assert equal $result.old_hash "babelold"
  assert str contains $result.content "hash: babelnew"
}

def test-lock-unquoted-nonscoped [] {
  # Non-scoped packages may appear without quotes in pnpm 10 lockfiles
  let content = "patchedDependencies:
  print-js@1.6.0:
    hash: oldhash123
    path: patches/print-js@1.6.0.patch
"
  let result = update-lock-content $content "print-js@1.6.0" "newhash456"

  assert equal $result.updated true
  assert equal $result.old_hash "oldhash123"
  assert str contains $result.content "hash: newhash456"
}

def test-lock-preserve [] {
  let content = "lockfileVersion: '9.0'

patchedDependencies:
  'lodash@4.17.21':
    hash: oldhash

packages:
  lodash@4.17.21:
    resolution: {integrity: sha512-xxx}
"
  let result = update-lock-content $content "lodash@4.17.21" "newhash"

  assert str contains $result.content "lockfileVersion: '9.0'"
  assert str contains $result.content "packages:"
  assert str contains $result.content "resolution: {integrity: sha512-xxx}"
}

# ============================================
# Tests for insert-lock-entry
# ============================================

def test-insert-new-entry [] {
  let content = "lockfileVersion: '9.0'

patchedDependencies:
  'existing@1.0.0':
    hash: existinghash
    path: patches/existing.patch

packages:
  existing@1.0.0:
    resolution: {integrity: sha512-xxx}
"
  let result = insert-lock-entry $content "newpkg@2.0.0" "newhash123" "patches/newpkg.patch"

  assert equal $result.inserted true
  assert str contains $result.content "'newpkg@2.0.0':"
  assert str contains $result.content "hash: newhash123"
  assert str contains $result.content "path: patches/newpkg.patch"
  # Existing entry should still be there
  assert str contains $result.content "'existing@1.0.0':"
}

def test-insert-scoped [] {
  let content = "patchedDependencies:
  'lodash@1.0.0':
    hash: lodash123
    path: patches/lodash.patch

packages:
"
  let result = insert-lock-entry $content "@alife/tarot@2.9.1" "tarothash" "patches/@alife__tarot@2.9.1.patch"

  assert equal $result.inserted true
  assert str contains $result.content "'@alife/tarot@2.9.1':"
  assert str contains $result.content "hash: tarothash"
  assert str contains $result.content "path: patches/@alife__tarot@2.9.1.patch"
}

def test-insert-no-section [] {
  let content = "lockfileVersion: '9.0'

packages:
  lodash@4.17.21:
    resolution: {integrity: sha512-xxx}
"
  let result = insert-lock-entry $content "newpkg@1.0.0" "hash123" "patches/newpkg.patch"

  assert equal $result null
}

def test-insert-preserve-existing [] {
  let content = "lockfileVersion: '9.0'

settings:
  autoInstallPeers: true

patchedDependencies:
  '@ali/pkg@1.0.0':
    hash: alihash
    path: patches/@ali__pkg@1.0.0.patch
  'lodash@4.17.21':
    hash: lodashhash
    path: patches/lodash.patch

packages:
  lodash@4.17.21:
    resolution: {integrity: sha512-xxx}
"
  let result = insert-lock-entry $content "@alife/new@1.0.0" "newhash" "patches/@alife__new@1.0.0.patch"

  assert equal $result.inserted true
  # All existing entries should be preserved
  assert str contains $result.content "'@ali/pkg@1.0.0':"
  assert str contains $result.content "'lodash@4.17.21':"
  assert str contains $result.content "'@alife/new@1.0.0':"
  # Other sections should be preserved
  assert str contains $result.content "lockfileVersion: '9.0'"
  assert str contains $result.content "settings:"
  assert str contains $result.content "packages:"
}

# ============================================
# inject-patch-hash-to-versions Tests
# ============================================

def test-inject-hash-importers [] {
  # For first-time patching, importers version field IS updated by inject function
  # using multiline regex to match package name on preceding line
  let content = "importers:
  .:
    dependencies:
      '@alife/u-touch':
        specifier: 2.1.5
        version: 2.1.5(@alife/next@1.19.32)
"
  let result = inject-patch-hash-to-versions $content "@alife/u-touch" "2.1.5" "testhash123"

  # Importer version field should be updated
  assert equal $result.updated true
  assert str contains $result.content "version: 2.1.5(patch_hash=testhash123)(@alife/next@1.19.32)"
}

def test-inject-hash-snapshots [] {
  let content = "snapshots:
  '@alife/u-touch@2.1.5(@alife/next@1.19.32)':
    dependencies:
      '@alife/next': 1.19.32
"
  let result = inject-patch-hash-to-versions $content "@alife/u-touch" "2.1.5" "snaphash456"

  assert equal $result.updated true
  assert str contains $result.content "'@alife/u-touch@2.1.5(patch_hash=snaphash456)(@alife/next@1.19.32)':"
}

def test-inject-hash-plus-format [] {
  let content = "snapshots:
  @alife+u-touch@2.1.5(@alife/next@1.19.32):
    dependencies:
      '@alife/next': 1.19.32
"
  let result = inject-patch-hash-to-versions $content "@alife/u-touch" "2.1.5" "plushash789"

  assert equal $result.updated true
  assert str contains $result.content "@alife+u-touch@2.1.5(patch_hash=plushash789)(@alife/next@1.19.32):"
}

def test-inject-hash-dedup [] {
  # Test that running inject on content that already has hash doesn't create double
  # (simulates running inject twice on the same content)
  let content = "snapshots:
  '@alife/u-touch@2.1.5(patch_hash=abc123)(@alife/next@1.19.32)':
    dependencies:
      '@alife/next': 1.19.32
"
  # Run inject again with same hash - should add another then dedup
  let result = inject-patch-hash-to-versions $content "@alife/u-touch" "2.1.5" "abc123"

  # The pattern matches and adds another hash, then dedup removes double -> single
  assert equal $result.updated false
  # Original content should be unchanged since we already have the hash
  # Actually: the pattern DOES match and adds, then dedup removes, so net change = 0
  # This means the function is idempotent when run twice
  let double_hash = "(patch_hash=abc123)(patch_hash=abc123)"
  assert equal ($result.content | str contains $double_hash) false
}

def test-inject-hash-no-change [] {
  # Content that doesn't match the pattern
  let content = "snapshots:
  'lodash@4.17.21':
    dependencies:
      foo: 1.0.0
"
  let result = inject-patch-hash-to-versions $content "@alife/u-touch" "2.1.5" "nohash"

  assert equal $result.updated false
  assert equal $result.content $content
}

def test-inject-hash-replace-old [] {
  # Test replacing old hash with new hash (re-patching scenario)
  # The old_hash parameter is used to do a global replacement
  let content = "importers:
  .:
    dependencies:
      '@alife/stage-supplier-selector':
        specifier: 2.5.0
        version: 2.5.0(patch_hash=oldhash123)(@alifd/next@1.27.29)
snapshots:
  '@alife/stage-supplier-selector@2.5.0(patch_hash=oldhash123)(@alifd/next@1.27.29)':
    dependencies:
      '@alifd/next': 1.27.29
"
  # Pass old_hash to enable global replacement
  let result = inject-patch-hash-to-versions $content "@alife/stage-supplier-selector" "2.5.0" "newhash456" "oldhash123"

  assert equal $result.updated true
  # Old hash should be removed and replaced with new hash in both importers and snapshots
  assert str contains $result.content "2.5.0(patch_hash=newhash456)(@alifd/next@1.27.29)"
  assert str contains $result.content "'@alife/stage-supplier-selector@2.5.0(patch_hash=newhash456)(@alifd/next@1.27.29)':"
  # Old hash should NOT be present
  assert equal ($result.content | str contains "oldhash123") false
}

def test-inject-hash-replace-existing-without-old-hash [] {
  # Test that existing patch_hash is replaced when old_hash is not provided
  # This handles the case of re-patching where update-lock-content found the entry
  # but the old_hash from version references wasn't captured
  let content = "importers:
  .:
    dependencies:
      print-js:
        specifier: ^1.6.0
        version: 1.6.0(patch_hash=fe0699817b866d2c68c7e28714a2eb9dce64cf29a789eebb0fb872fe257fcd00)
snapshots:
  print-js@1.6.0(patch_hash=fe0699817b866d2c68c7e28714a2eb9dce64cf29a789eebb0fb872fe257fcd00): {}
"
  # Do NOT pass old_hash - the function should detect and replace existing hash
  let result = inject-patch-hash-to-versions $content "print-js" "1.6.0" "1900b1c22011e31a1d84e5562145b38f69842b4552925d7b4530a954487724fc"

  assert equal $result.updated true
  # Should have only the new hash, not double hashes
  assert str contains $result.content "1.6.0(patch_hash=1900b1c22011e31a1d84e5562145b38f69842b4552925d7b4530a954487724fc)"
  # Old hash should NOT be present
  assert equal ($result.content | str contains "fe0699817b866d2c68c7e28714a2eb9dce64cf29a789eebb0fb872fe257fcd00") false
  # Should NOT have double patch_hash
  assert equal ($result.content | str contains "(patch_hash=1900b1c22011e31a1d84e5562145b38f69842b4552925d7b4530a954487724fc)(patch_hash=") false
}

def test-inject-hash-nonscoped-snapshots [] {
  # Test non-scoped package (like lodash) snapshot entries
  # Only snapshot entries should get patch_hash, NOT packages entries (with resolution:)
  let content = "packages:
  lodash@4.17.21:
    resolution: {integrity: sha512-xxx}

snapshots:
  lodash@4.17.21: {}

  other-pkg@1.0.0:
    dependencies:
      lodash: 4.17.21
"
  let result = inject-patch-hash-to-versions $content "lodash" "4.17.21" "lodashpatch789"

  assert equal $result.updated true
  # Snapshot entry should have patch_hash added
  assert str contains $result.content "lodash@4.17.21(patch_hash=lodashpatch789): {}"
  # Packages entry should NOT have patch_hash (keeps resolution info)
  assert str contains $result.content "packages:\n  lodash@4.17.21:\n    resolution:"
  # Dependency value should have patch_hash
  assert str contains $result.content "lodash: 4.17.21(patch_hash=lodashpatch789)"
  # other-pkg should NOT be affected
  assert str contains $result.content "other-pkg@1.0.0:"
}

def test-inject-hash-nonscoped-importers [] {
  # Test non-scoped package importer version fields
  # Non-scoped packages don't have quotes around the name in YAML
  let content = "importers:
  .:
    dependencies:
      lodash:
        specifier: ^4.17.21
        version: 4.17.21
      '@alife/other':
        specifier: ^1.0.0
        version: 1.0.0(@dep@2.0.0)
"
  let result = inject-patch-hash-to-versions $content "lodash" "4.17.21" "lodashimport456"

  # lodash version without peer deps should be updated (version at end of line)
  assert equal $result.updated true
  assert str contains $result.content "version: 4.17.21(patch_hash=lodashimport456)"
}

# ============================================
# Cumulative Mode Tests
# ============================================

def test-revert-patch-success [] {
  # Setup: Create a package directory with a patched file
  let test_dir = $"($env.FIXTURES_DIR)/revert-test"
  rm -rf $test_dir
  mkdir $test_dir

  # Create the "patched" version (what we start with after pnpm applies patch)
  let patched_content = "module.exports = { patched: true }
"
  $patched_content | save $"($test_dir)/index.js"

  # Create a patch that represents the change from original to patched
  # When we revert, we should go from patched -> original
  let patch_content = "diff --git a/index.js b/index.js
index 1234567..abcdefg 100644
--- a/index.js
+++ b/index.js
@@ -1 +1 @@
-module.exports = {}
+module.exports = { patched: true }
"
  let patch_file = $"($env.FIXTURES_DIR)/revert-test.patch"
  $patch_content | save $patch_file

  # Verify starting state (patched version)
  let before_content = open $"($test_dir)/index.js" --raw
  assert str contains $before_content "patched: true"

  # Now test reverting - should change back to original
  let result = revert-patch $test_dir $patch_file

  assert equal $result true
  let after_content = open $"($test_dir)/index.js" --raw
  # After revert, should have the original content (no "patched: true")
  assert str contains $after_content "module.exports = {}"
  assert equal ($after_content | str contains "patched: true") false

  # Cleanup
  rm -rf $test_dir
  rm -f $patch_file
}

def test-revert-patch-failure [] {
  # Setup: Create a package directory with content that doesn't match the patch
  let test_dir = $"($env.FIXTURES_DIR)/revert-fail-test"
  rm -rf $test_dir
  mkdir $test_dir

  # Create content that doesn't match what the patch expects
  "completely different content that wont match
" | save $"($test_dir)/index.js"

  # Create a patch that expects different content
  let patch_content = "diff --git a/index.js b/index.js
index 1234567..abcdefg 100644
--- a/index.js
+++ b/index.js
@@ -1 +1 @@
-module.exports = {}
+module.exports = { patched: true }
"
  let patch_file = $"($env.FIXTURES_DIR)/revert-fail-test.patch"
  $patch_content | save $patch_file

  # Test reverting should fail (content doesn't match either state)
  let result = revert-patch $test_dir $patch_file

  assert equal $result false

  # Cleanup
  rm -rf $test_dir
  rm -f $patch_file
}

def test-cumulative-patch-generation [] {
  # This test verifies the cumulative mode workflow:
  # 1. Start with a "patched" package (simulating what pnpm installs with existing patch)
  # 2. Revert to get the original in original/
  # 3. Keep the patched version in modified/ and add new changes
  # 4. Generate diff should contain BOTH old patch changes AND new changes

  let test_dir = $"($env.FIXTURES_DIR)/cumulative-test"
  rm -rf $test_dir
  mkdir $"($test_dir)/original" $"($test_dir)/modified"

  let basename = "test-pkg"

  # Create the "patched" version (what pnpm would have after applying existing patch)
  # Old patch changes: added "oldPatchChange: true"
  let patched_content = "module.exports = {
  oldPatchChange: true,
  original: 'value'
}
"
  mkdir $"($test_dir)/original/($basename)"
  mkdir $"($test_dir)/modified/($basename)"
  $patched_content | save $"($test_dir)/original/($basename)/index.js"
  $patched_content | save $"($test_dir)/modified/($basename)/index.js"

  # Create the existing patch (original -> patched)
  let existing_patch = "diff --git a/index.js b/index.js
index 1234567..abcdefg 100644
--- a/index.js
+++ b/index.js
@@ -1,3 +1,4 @@
 module.exports = {
+  oldPatchChange: true,
   original: 'value'
 }
"
  let patch_file = $"($test_dir)/existing.patch"
  $existing_patch | save $patch_file

  # Step 1: Revert the patch in original/ to get the TRUE original
  let revert_result = revert-patch $"($test_dir)/original/($basename)" $patch_file
  assert equal $revert_result true

  # Verify original/ now has the true original (no oldPatchChange)
  let original_content = open $"($test_dir)/original/($basename)/index.js" --raw
  assert equal ($original_content | str contains "oldPatchChange") false

  # Step 2: Add NEW changes to modified/ (which still has the old patch)
  let modified_file = $"($test_dir)/modified/($basename)/index.js"
  let modified_content = open $modified_file --raw
  let new_content = $modified_content | str replace "original: 'value'" "original: 'value',
  newChange: 'added'"
  $new_content | save -f $modified_file

  # Step 3: Generate the cumulative patch
  let cumulative_patch = generate-patch $test_dir $basename

  # Step 4: Verify the cumulative patch contains BOTH old and new changes
  # Old change: "oldPatchChange: true"
  # New change: "newChange: 'added'"
  assert str contains $cumulative_patch "oldPatchChange"
  assert str contains $cumulative_patch "newChange"

  # Cleanup
  rm -rf $test_dir
}

# ============================================
# Store-related function tests
# ============================================

def test-integrity-to-store-path [] {
  # Test with a known sha512 integrity hash
  # sha512-v2kDEe57lecTulaDIuNTPy3Ry4gLGJ6Z1O3vE1krgXZNrsQ+LFTGHVxVjcXPs17LhbZVGedAJv8XZ1tvj5FvSg==
  # Expected hex: bf690311ee7b95e713ba568322e3533f2dd1cb880b189e99d4edef13592b81764daec43e2c54c61d5c558dc5cfb35ecb85b65519e74026ff17675b6f8f916f4a
  let integrity = "sha512-v2kDEe57lecTulaDIuNTPy3Ry4gLGJ6Z1O3vE1krgXZNrsQ+LFTGHVxVjcXPs17LhbZVGedAJv8XZ1tvj5FvSg=="
  let result = integrity-to-store-path $integrity

  assert equal ($result | is-not-empty) true
  assert equal $result.bucket "bf"
  assert equal ($result.hash | str starts-with "690311ee7b95e713ba56") true
}

def test-integrity-to-store-path-invalid [] {
  # Test with empty string
  let result1 = integrity-to-store-path ""
  assert equal $result1 null

  # Test with non-sha512 hash
  let result2 = integrity-to-store-path "md5-abc123"
  assert equal $result2 null

  # Test with invalid base64
  let result3 = integrity-to-store-path "sha512-!!invalid!!"
  assert equal $result3 null
}

def test-get-package-integrity [] {
  let lock_content = "lockfileVersion: '9.0'

packages:

  lodash@4.17.21:
    resolution: {integrity: sha512-v2kDEe57lecTulaDIuNTPy3Ry4gLGJ6Z1O3vE1krgXZNrsQ+LFTGHVxVjcXPs17LhbZVGedAJv8XZ1tvj5FvSg==}

  moment@2.30.1:
    resolution: {integrity: sha512-uEmtNhbDOrWPFS+hdjFCBfy9f2YoyzRpwcl+DqpC6taX21FzsTLQVbMV/W7PzNSX6x/bhC1zA3c2UQ5NzH6how==}
"

  let result = get-package-integrity $lock_content "lodash" "4.17.21"
  assert equal $result "sha512-v2kDEe57lecTulaDIuNTPy3Ry4gLGJ6Z1O3vE1krgXZNrsQ+LFTGHVxVjcXPs17LhbZVGedAJv8XZ1tvj5FvSg=="

  # Test non-existent package
  let result2 = get-package-integrity $lock_content "nonexistent" "1.0.0"
  assert equal $result2 ""
}

def test-get-package-integrity-quoted [] {
  # Test scoped packages with quotes (as they appear in real lockfiles)
  let lock_content = "lockfileVersion: '9.0'

packages:

  '@alife/stage-supplier-selector@2.5.0':
    resolution: {integrity: sha512-XmgJ39llRCWbHpJKUhvzA52o6Hn8utCRSjZ6joMC1vCShIIHXFA0GP9QICgEKshRPnjDtm6k1V5oYqKnHHFq4Q==}
    peerDependencies:
      '@alifd/next': 1.x

  '@scope/another-pkg@1.0.0':
    resolution: {integrity: sha512-abcdefg123456789==}
"

  let result = get-package-integrity $lock_content "@alife/stage-supplier-selector" "2.5.0"
  assert equal $result "sha512-XmgJ39llRCWbHpJKUhvzA52o6Hn8utCRSjZ6joMC1vCShIIHXFA0GP9QICgEKshRPnjDtm6k1V5oYqKnHHFq4Q=="

  let result2 = get-package-integrity $lock_content "@scope/another-pkg" "1.0.0"
  assert equal $result2 "sha512-abcdefg123456789=="
}

def test-get-package-integrity-skip-patched [] {
  # Test that we skip patchedDependencies section and find the packages section
  # This simulates a real lockfile where the same package appears in both sections
  let lock_content = "lockfileVersion: '9.0'

patchedDependencies:
  '@alife/stage-supplier-selector@2.5.0':
    hash: pcr7azd7plg2cyjc3arhi3u3by
    path: patches/@alife__stage-supplier-selector@2.5.0.patch
  '@alife/other-pkg@1.0.0':
    hash: xyz123
    path: patches/@alife__other-pkg@1.0.0.patch

packages:

  '@alife/stage-supplier-selector@2.5.0':
    resolution: {integrity: sha512-CorrectIntegrityHash==}
    peerDependencies:
      '@alifd/next': 1.x

  '@alife/other-pkg@1.0.0':
    resolution: {integrity: sha512-OtherPkgIntegrity==}
"

  # Should find the packages section entry, not the patchedDependencies one
  let result = get-package-integrity $lock_content "@alife/stage-supplier-selector" "2.5.0"
  assert equal $result "sha512-CorrectIntegrityHash=="

  let result2 = get-package-integrity $lock_content "@alife/other-pkg" "1.0.0"
  assert equal $result2 "sha512-OtherPkgIntegrity=="
}

def test-restore-from-store [] {
  # Create a mock store structure that mimics pnpm's content-addressable store
  let test_dir = $"($env.FIXTURES_DIR)/store-test"
  let mock_store = $"($test_dir)/mock-store"
  let target_dir = $"($test_dir)/restored-pkg"

  rm -rf $test_dir
  mkdir $test_dir

  # Create mock file content
  let file_content = "module.exports = { original: true };\n"

  # Calculate the file's sha512 hash (same algorithm pnpm uses)
  let file_sha512_binary = $file_content | hash sha256 --binary
  let file_sha512_hex = $file_sha512_binary | encode hex | str downcase
  let file_bucket = $file_sha512_hex | str substring 0..<2
  let file_hash_rest = $file_sha512_hex | str substring 2..

  # Create the file in mock store
  mkdir $"($mock_store)/files/($file_bucket)"
  $file_content | save $"($mock_store)/files/($file_bucket)/($file_hash_rest)"

  # Create an index.json for the package
  # The package integrity is just a placeholder to locate the index file
  let pkg_bucket = "aa"
  # sha512 produces 128 hex chars, minus 2 for bucket = 126 chars
  let pkg_hash = "00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  mkdir $"($mock_store)/files/($pkg_bucket)"

  # Create integrity string for the file (must be sha512 format)
  let file_sha512_base64 = $file_sha512_binary | encode base64
  let file_integrity = $"sha512-($file_sha512_base64)"

  let index_content = {
    name: "test-pkg"
    version: "1.0.0"
    files: {
      "index.js": {
        integrity: $file_integrity
        mode: 420
        size: ($file_content | str length)
      }
    }
  }

  $index_content | to json | save $"($mock_store)/files/($pkg_bucket)/($pkg_hash)-index.json"

  # The package integrity that will locate the index.json
  # We need to construct a sha512 that decodes to aa + pkg_hash
  let pkg_integrity = "sha512-qgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

  # Test restore
  let result = restore-from-store $mock_store $pkg_integrity $target_dir

  # Verify the file was restored
  assert equal $result true
  assert equal ($"($target_dir)/index.js" | path exists) true

  let restored_content = open $"($target_dir)/index.js" --raw
  assert equal $restored_content $file_content

  # Cleanup
  rm -rf $test_dir
}
