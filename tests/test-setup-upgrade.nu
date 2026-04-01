#!/usr/bin/env nu
# Description:
#   Unit tests for setup-termix upgrade target resolution
# Usage:
#   nu tests/test-setup-upgrade.nu

use std assert
use utils.nu [run_tests]
use ../actions/setup.nu [normalize-setup-tool, get-setup-targets]

def main [] {
  let tests = [
    { name: 'normalize-setup-tool maps nushell alias to nu', execute: { test-normalize-setup-tool } }
    { name: 'get-setup-targets returns all binaries by default', execute: { test-get-setup-targets-default } }
    { name: 'get-setup-targets returns only requested binary', execute: { test-get-setup-targets-single } }
    { name: 'normalize-setup-tool rejects unsupported tools', execute: { test-normalize-setup-tool-invalid } }
  ]

  run_tests $env.PROCESS_PATH $tests
}

def test-normalize-setup-tool [] {
  assert equal (normalize-setup-tool 'nu') 'nu'
  assert equal (normalize-setup-tool 'nushell') 'nu'
  assert equal (normalize-setup-tool 'just') 'just'
}

def test-get-setup-targets-default [] {
  assert equal (get-setup-targets) [nu fzf just s5cmd]
}

def test-get-setup-targets-single [] {
  assert equal (get-setup-targets 'fzf') ['fzf']
  assert equal (get-setup-targets 'nushell') ['nu']
}

def test-normalize-setup-tool-invalid [] {
  let failed = try {
    normalize-setup-tool 'termix-nu' | ignore
    false
  } catch {
    true
  }

  assert equal $failed true
}
