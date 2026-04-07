#!/usr/bin/env nu
# Description:
#   Unit tests for terp-assets agent mode
# Usage:
#   nu tests/test-terp-assets.nu

use std assert
use utils.nu [run_tests]

def main [] {
  run_tests $env.PROCESS_PATH [
    { name: 'terp-assets detect returns JSON payload in agent mode', execute: { test-detect-agent-json } }
    { name: 'terp-assets download requires explicit modules in agent mode', execute: { test-download-missing-modules } }
    { name: 'terp-assets transfer requires explicit yes in agent mode', execute: { test-transfer-requires-yes } }
    { name: 'terp-assets revert requires explicit revision in agent mode', execute: { test-revert-missing-revision } }
    { name: 'terp-assets detect text mode does not echo summary record', execute: { test-detect-text-no-summary-record } }
    { name: 'terp-assets detect text mode prints stats after module summary', execute: { test-detect-stat-order } }
  ]
}

def repo-root [] {
  ([$env.FILE_PWD '..'] | path join | path expand)
}

def fixture-home [] {
  ([(repo-root) tests fixtures terp-assets-home] | path join)
}

def fixture-dir [] {
  ([(repo-root) tests fixtures] | path join)
}

def run-terp-assets [command: string] {
  let root = repo-root
  let fixtures = fixture-dir
  with-env {
    TERMIX_DIR: (fixture-home),
    TERP_ASSETS_ENABLE_FIXTURES: true,
    TERP_ASSETS_FIXTURE_LATEST: ([ $fixtures terp-assets-latest.json ] | path join),
    TERP_ASSETS_FIXTURE_REVISIONS: ([ $fixtures terp-assets-revisions.json ] | path join),
    DICE_OPERATOR_NAME: 'Tester',
  } {
    nu -c $'overlay use ($root)/actions/terp-assets.nu; ($command)' | complete
  }
}

def parse-json [text: string] {
  $text | str trim | from json
}

def test-detect-agent-json [] {
  let result = run-terp-assets 'terp assets detect --from dev --agent'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'detect'
  assert equal $payload.data.mountpoint 'dev'
  assert equal $payload.data.raw.counts.total 2
  assert equal $payload.data.raw.modules.0.module 'base'
}

def test-download-missing-modules [] {
  let result = run-terp-assets 'terp assets download --from dev --agent'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'INTERACTION_REQUIRED'
  assert equal $payload.error.details.required.0 'modules'
  assert equal $payload.error.details.availableModules.0 'base'
}

def test-transfer-requires-yes [] {
  let result = run-terp-assets 'terp assets transfer base --from dev --to terp-dev --dest-store oss --agent'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'MUTATION_NOT_CONFIRMED'
}

def test-revert-missing-revision [] {
  let result = run-terp-assets 'terp assets revert base --to dev --dest-store oss --agent --yes'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'INTERACTION_REQUIRED'
  assert equal $payload.error.details.required.0 'revision'
  assert equal $payload.error.details.availableRevisions.0 'base-3.0.2506'
}

def test-detect-text-no-summary-record [] {
  let result = run-terp-assets 'terp assets detect --from dev'
  assert equal $result.exit_code 0
  assert ($result.stdout | str contains 'Latest metadata of')
  assert not ($result.stdout | str contains 'mountpoint   dev')
  assert not ($result.stdout | str contains '{"success":true')
}

def test-detect-stat-order [] {
  let result = run-terp-assets 'terp assets detect --from dev --stat'
  assert equal $result.exit_code 0
  let summaryPos = ($result.stdout | str index-of 'Total modules:')
  let statsPos = ($result.stdout | str index-of 'Static Assets Statistics:')
  assert greater $summaryPos (-1)
  assert greater $statsPos (-1)
  assert greater $statsPos $summaryPos
}
