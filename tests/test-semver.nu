#!/usr/bin/env nu
# Description:
#   Unit tests for is-semver and parse-semver
# Usage:
#   nu tests/test-semver.nu

use std assert
use utils.nu [run_tests]
use ../utils/common.nu [is-semver, parse-semver]

def main [] {
  run_tests $env.PROCESS_PATH [
    # is-semver: valid versions
    { name: 'is-semver accepts simple version', execute: { test-is-semver-simple } }
    { name: 'is-semver accepts v prefix', execute: { test-is-semver-v-prefix } }
    { name: 'is-semver accepts pre-release', execute: { test-is-semver-prerelease } }
    { name: 'is-semver accepts build metadata', execute: { test-is-semver-build } }
    { name: 'is-semver accepts pre-release with build', execute: { test-is-semver-pre-build } }
    { name: 'is-semver accepts zero versions', execute: { test-is-semver-zeros } }
    { name: 'is-semver accepts complex pre-release', execute: { test-is-semver-complex-pre } }
    # is-semver: invalid versions
    { name: 'is-semver rejects empty string', execute: { test-is-semver-empty } }
    { name: 'is-semver rejects missing patch', execute: { test-is-semver-missing-patch } }
    { name: 'is-semver rejects leading zeros', execute: { test-is-semver-leading-zeros } }
    { name: 'is-semver rejects plain text', execute: { test-is-semver-text } }
    { name: 'is-semver rejects extra segments', execute: { test-is-semver-extra-segments } }
    # parse-semver: parsing results
    { name: 'parse-semver parses simple version', execute: { test-parse-simple } }
    { name: 'parse-semver strips v prefix', execute: { test-parse-v-prefix } }
    { name: 'parse-semver parses pre-release', execute: { test-parse-prerelease } }
    { name: 'parse-semver parses build metadata', execute: { test-parse-build } }
    { name: 'parse-semver parses full version', execute: { test-parse-full } }
    { name: 'parse-semver parses complex pre-release with hyphens', execute: { test-parse-complex-pre } }
    { name: 'parse-semver errors on invalid input', execute: { test-parse-invalid } }
  ]
}

# ============================================
# is-semver tests: valid versions
# ============================================

def test-is-semver-simple [] {
  assert equal (is-semver '1.2.3') true
  assert equal (is-semver '0.0.1') true
  assert equal (is-semver '10.20.30') true
}

def test-is-semver-v-prefix [] {
  assert equal (is-semver 'v1.2.3') true
  assert equal (is-semver 'v0.1.0') true
}

def test-is-semver-prerelease [] {
  assert equal (is-semver '1.0.0-alpha') true
  assert equal (is-semver '1.0.0-alpha.1') true
  assert equal (is-semver '1.0.0-0.3.7') true
  assert equal (is-semver '1.0.0-x.7.z.92') true
}

def test-is-semver-build [] {
  assert equal (is-semver '1.0.0+build.123') true
  assert equal (is-semver '1.0.0+20130313144700') true
}

def test-is-semver-pre-build [] {
  assert equal (is-semver '1.0.0-beta+exp.sha.5114f85') true
  assert equal (is-semver 'v2.5.8-rc.1+exp.sha.511c985') true
}

def test-is-semver-zeros [] {
  assert equal (is-semver '0.0.0') true
  assert equal (is-semver '0.0.0-alpha') true
}

def test-is-semver-complex-pre [] {
  assert equal (is-semver '1.0.0-alpha-beta.1') true
  assert equal (is-semver '1.0.0-rc.1') true
}

# ============================================
# is-semver tests: invalid versions
# ============================================

def test-is-semver-empty [] {
  assert equal (is-semver '') false
}

def test-is-semver-missing-patch [] {
  assert equal (is-semver '1.2') false
  assert equal (is-semver '1') false
}

def test-is-semver-leading-zeros [] {
  assert equal (is-semver '01.2.3') false
  assert equal (is-semver '1.02.3') false
  assert equal (is-semver '1.2.03') false
}

def test-is-semver-text [] {
  assert equal (is-semver 'not-a-version') false
  assert equal (is-semver 'abc') false
}

def test-is-semver-extra-segments [] {
  assert equal (is-semver '1.2.3.4') false
}

# ============================================
# parse-semver tests
# ============================================

def test-parse-simple [] {
  let r = parse-semver '1.2.3'
  assert equal $r.major 1
  assert equal $r.minor 2
  assert equal $r.patch 3
  assert equal $r.pre ''
  assert equal $r.build ''
}

def test-parse-v-prefix [] {
  let r = parse-semver 'v3.0.1'
  assert equal $r.major 3
  assert equal $r.minor 0
  assert equal $r.patch 1
}

def test-parse-prerelease [] {
  let r = parse-semver '1.0.0-alpha.1'
  assert equal $r.major 1
  assert equal $r.minor 0
  assert equal $r.patch 0
  assert equal $r.pre 'alpha.1'
  assert equal $r.build ''
}

def test-parse-build [] {
  let r = parse-semver '1.0.0+20130313144700'
  assert equal $r.major 1
  assert equal $r.minor 0
  assert equal $r.patch 0
  assert equal $r.pre ''
  assert equal $r.build '20130313144700'
}

def test-parse-full [] {
  let r = parse-semver 'v2.5.8-rc.1+exp.sha.511c985'
  assert equal $r.major 2
  assert equal $r.minor 5
  assert equal $r.patch 8
  assert equal $r.pre 'rc.1'
  assert equal $r.build 'exp.sha.511c985'
}

def test-parse-complex-pre [] {
  let r = parse-semver '1.0.0-alpha-beta.1'
  assert equal $r.major 1
  assert equal $r.minor 0
  assert equal $r.patch 0
  assert equal $r.pre 'alpha-beta.1'
}

def test-parse-invalid [] {
  let errored = try { parse-semver 'not-valid'; false } catch { true }
  assert equal $errored true
}
