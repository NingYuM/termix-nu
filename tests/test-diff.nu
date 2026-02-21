#!/usr/bin/env nu
# Description:
#   Unit tests for code-review diff utilities
# Usage:
#   nu tests/test-diff.nu

use std assert
use ../actions/code-review.nu [is-safe-git, generate-include-args, generate-exclude-args]

# Get the unicode width of the input string
def get-uw [] { $in | str stats | get unicode-width }

def main [] {
  $env.config.table.mode = 'psql'

  let tests = [
    { name: 'is-safe-git should work as expected', execute: { test-is-safe-git } }
    { name: 'generate-include-arg should work as expected', execute: { test-generate-include-args } }
    { name: 'generate-exclude-arg should work as expected', execute: { test-generate-exclude-args } }
    { name: 'generate-exclude-arg and generate-include-arg should work as expected', execute: { test-include-exclude-combined } }
    { name: 'generate-exclude-arg and generate-include-arg should work with git show', execute: { test-include-exclude-git-show } }
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

def test-is-safe-git [] {
  assert equal (is-safe-git 'git diff') true
  assert equal (is-safe-git 'git show') true
  assert equal (is-safe-git 'git log') false
  assert equal (is-safe-git 'git checkout') false
  assert equal (is-safe-git 'git show 0dd0eb5') true
  assert equal (is-safe-git 'git show HEAD') true
  assert equal (is-safe-git 'git show head~1') true
  assert equal (is-safe-git 'git diff HEAD~2') true
  assert equal (is-safe-git 'git diff head~3 main') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5') true
  assert equal (is-safe-git 'git show 2393375 | less') false
  assert equal (is-safe-git 'git show 2393375>diff.patch') false
  assert equal (is-safe-git 'git show 2393375 o+e>diff.patch') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 nu/*') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*') true
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* && rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* || rm -rf abc') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -f ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/*; rm -rf ./*') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* > out.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* >> out.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* < in.txt') false
  assert equal (is-safe-git 'git diff f536acc 0dd0eb5 :!nu/* << in.txt') false
  assert equal (is-safe-git 'git show head:utils/common.nu') true
  assert equal (is-safe-git 'git show HEAD:utils/common.nu') true
}

def test-generate-include-args [] {
  assert equal (git diff d370863 631b71f --name-only ...(generate-include-args run/,dotfiles/,Dockerfile) | lines | length) 5
  assert equal (git diff d370863 631b71f --name-only ...(generate-include-args run/,dotfiles/,Dockerfile,*.nu) | lines | length) 7
  assert equal (git diff d370863 631b71f ...(generate-include-args run/,Dockerfile) | get-uw) 2529
  assert equal (git diff d370863 631b71f ...(generate-include-args run/*,Dockerfile) | get-uw) 2529
  assert equal (git diff d370863 631b71f ...(generate-include-args *.nu,Dockerfile) | get-uw) 11023
}

def test-generate-exclude-args [] {
  assert equal (git diff d370863 631b71f --name-only ...(generate-exclude-args run/,dotfiles/,Dockerfile) | lines | length) 9
  assert equal (git diff d370863 631b71f --name-only ...(generate-exclude-args run/,dotfiles/,Dockerfile,*.nu) | lines | length) 7
  assert equal (git diff d370863 631b71f ...(generate-exclude-args run/,Dockerfile) | get-uw) 20280
  assert equal (git diff d370863 631b71f ...(generate-exclude-args run/*,Dockerfile) | get-uw) 20280
  assert equal (git diff d370863 631b71f ...(generate-exclude-args *.nu,Dockerfile) | get-uw) 11786
}

def test-include-exclude-combined [] {
  assert equal (git diff d370863 631b71f ...(generate-include-args run/,Dockerfile) ...(generate-exclude-args run/,Dockerfile) | get-uw) 0
  assert equal (git diff d370863 631b71f ...(generate-include-args Dockerfile) ...(generate-exclude-args run/,Dockerfile) | get-uw) 0
  assert equal (git diff d370863 631b71f ...(generate-include-args Dockerfile) ...(generate-exclude-args run/) | get-uw) 2186
}

def test-include-exclude-git-show [] {
  assert equal (git show 371b75c ...(generate-include-args actions/) ...(generate-exclude-args utils/) | get-uw) 2283
  assert equal (git show 371b75c ...(generate-include-args actions/) ...(generate-exclude-args actions/) | get-uw) 0
  assert equal (git show 371b75c ...(generate-include-args utils/) | get-uw) 992
  assert equal (git show 371b75c ...(generate-exclude-args utils/) | get-uw) 2283
}
