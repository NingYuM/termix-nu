#!/usr/bin/env nu
# Description:
#   Unit tests for compare-ver
# Usage:
#   nu tests/test-compare-ver.nu

use std assert
use ../utils/common.nu [compare-ver]

def main [] {
  $env.config.table.mode = 'psql'

  let tests = [
    { name: 'compare-ver basic version comparison', execute: { test-basic-comparison } }
    { name: 'compare-ver pre-release comparison', execute: { test-prerelease-comparison } }
    { name: 'compare-ver numeric pre-release comparison', execute: { test-numeric-prerelease } }
    { name: 'compare-ver build metadata handling', execute: { test-build-metadata } }
    { name: 'compare-ver v prefix handling', execute: { test-v-prefix } }
  ]

  let results = $tests | each { |test| run_test $test }

  print -n (char nl)
  print_results $results
  print_summary $results

  if ($results | any { |test| $test.result == 'FAIL' }) {
    exit 1
  }
}

# ============================================
# Test Runner Utilities
# ============================================

def print_results [results: list<record<name: string, result: string>>] {
  let display_table = $results | update result { |row|
    let emoji = if ($row.result == 'PASS') { $'(ansi g)√(ansi rst)' } else { $'(ansi r)×(ansi rst)' }
    $'($emoji) ($row.result)'
  }

  if ('GITHUB_ACTIONS' in $env) {
    print ($display_table | to md --pretty)
  } else {
    print $display_table
  }

  let failed = $results | where result == 'FAIL'
  for test in $failed {
    print $"\n($test.name): ($test.error)"
  }
}

def print_summary [results: list<record<name: string, result: string>>]: nothing -> bool {
  let success = $results | where ($it.result == 'PASS') | length
  let failure = $results | where ($it.result == 'FAIL') | length
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
    { result: 'PASS', name: $test.name, error: '' }
  } catch { |error|
    { result: 'FAIL', name: $test.name, error: $'($error.msg)' }
  }
}

# ============================================
# Tests
# ============================================

def test-basic-comparison [] {
  assert equal (compare-ver '1.2.3' '1.2.0') 1
  assert equal (compare-ver '2.0.0' '2.0.0') 0
  assert equal (compare-ver '1.9.9' '2.0.0') (-1)
}

def test-prerelease-comparison [] {
  assert equal (compare-ver '1.2.3-beta' '1.2.3') (-1)
  assert equal (compare-ver '1.2.3' '1.2.3-beta') 1
  assert equal (compare-ver '1.2.3-alpha' '1.2.3-beta') (-1)
}

def test-numeric-prerelease [] {
  assert equal (compare-ver '1.2.3-alpha.1' '1.2.3-alpha.2') (-1)
  assert equal (compare-ver '1.2.3-alpha.1' '1.2.3-alpha.beta') (-1)
}

def test-build-metadata [] {
  assert equal (compare-ver '1.2.3+build1' '1.2.3+build2') 0
  assert equal (compare-ver '1.2.3-alpha+build1' '1.2.3-alpha+build2') 0
}

def test-v-prefix [] {
  assert equal (compare-ver 'v1.2.3' '1.2.4') (-1)
}
