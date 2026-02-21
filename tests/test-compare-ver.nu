#!/usr/bin/env nu
# Description:
#   Unit tests for compare-ver
# Usage:
#   nu tests/test-compare-ver.nu

use std assert
use utils.nu [run_tests]
use ../utils/common.nu [compare-ver]

def main [] {
  run_tests $env.PROCESS_PATH [
    { name: 'compare-ver basic version comparison', execute: { test-basic-comparison } }
    { name: 'compare-ver pre-release comparison', execute: { test-prerelease-comparison } }
    { name: 'compare-ver numeric pre-release comparison', execute: { test-numeric-prerelease } }
    { name: 'compare-ver build metadata handling', execute: { test-build-metadata } }
    { name: 'compare-ver v prefix handling', execute: { test-v-prefix } }
  ]
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
