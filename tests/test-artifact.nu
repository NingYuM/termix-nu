#!/usr/bin/env nu
# Description:
#   Unit tests for artifact agent-friendly actions
# Usage:
#   nu tests/test-artifact.nu

use std assert
use utils.nu [run_tests]

def main [] {
  run_tests $env.PROCESS_PATH [
    { name: 'artifact list-sources returns JSON payload', execute: { test-list-sources } }
    { name: 'artifact list-destinations returns JSON payload', execute: { test-list-destinations } }
    { name: 'artifact list-releases returns fixture-backed JSON payload', execute: { test-list-releases } }
    { name: 'artifact show-release returns fixture-backed JSON payload', execute: { test-show-release } }
    { name: 'artifact show-deploy-order returns fixture-backed JSON payload', execute: { test-show-deploy-order } }
    { name: 'artifact list-deploy-groups requires version in agent mode', execute: { test-list-deploy-groups-missing-version } }
    { name: 'artifact list-deploy-groups returns fixture-backed JSON payload', execute: { test-list-deploy-groups } }
    { name: 'artifact produce requires explicit yes in agent mode', execute: { test-produce-non-interactive } }
    { name: 'artifact consume dry-run requires version in agent mode', execute: { test-consume-dry-run-missing-version } }
    { name: 'artifact deploy dry-run requires version in agent mode', execute: { test-deploy-dry-run-missing-version } }
    { name: 'artifact deploy dry-run returns normalized success schema', execute: { test-deploy-dry-run } }
  ]
}

def repo-root [] {
  ([$env.FILE_PWD '..'] | path join | path expand)
}

def run-artifact [command: string] {
  let root = repo-root
  TERMIX_DIR=$root nu -c $'overlay use actions/artifact.nu; ($command)' | complete
}

def run-artifact-with-fixtures [command: string] {
  let root = repo-root
  let fixture_dir = [$root tests fixtures] | path join
  with-env {
    TERMIX_DIR: $root,
    ARTIFACT_ENABLE_FIXTURES: true,
    ARTIFACT_FIXTURE_RELEASE_CANDIDATES: ([$fixture_dir artifact-release-candidates.json] | path join),
    ARTIFACT_FIXTURE_RELEASE_QUERY: ([$fixture_dir artifact-release-query.json] | path join),
    ARTIFACT_FIXTURE_RELEASE_DETAIL: ([$fixture_dir artifact-release-detail.json] | path join),
    ARTIFACT_FIXTURE_DEPLOY_DETAIL: ([$fixture_dir artifact-deploy-detail.json] | path join),
  } {
    nu -c $'overlay use actions/artifact.nu; ($command)' | complete
  }
}

def parse-json [text: string] {
  $text | str trim | from json
}

def test-list-sources [] {
  let result = run-artifact 'artifacts list-sources --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'list-sources'
  assert greater (($payload.data.raw | length)) 0
}

def test-list-destinations [] {
  let result = run-artifact 'artifacts list-destinations --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'list-destinations'
  assert greater (($payload.data.raw | length)) 0
}

def test-list-releases [] {
  let result = run-artifact-with-fixtures 'artifacts list-releases --to terp --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'list-releases'
  assert equal $payload.data.raw.0.releaseId 'rel-001'
}

def test-show-release [] {
  let result = run-artifact-with-fixtures 'artifacts show-release --to terp --version R.3.0.2506+20250721162706.810 --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'show-release'
  assert equal $payload.data.version 'R.3.0.2506+20250721162706.810'
  assert equal $payload.data.releaseId 'rel-001'
}

def test-show-deploy-order [] {
  let result = run-artifact-with-fixtures 'artifacts show-deploy-order --to terp --doid do-001 --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'show-deploy-order'
  assert equal $payload.data.deployOrderId 'do-001'
}

def test-list-deploy-groups-missing-version [] {
  let result = run-artifact 'artifacts list-deploy-groups --output json --non-interactive'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'MISSING_VERSION'
}

def test-list-deploy-groups [] {
  let result = run-artifact-with-fixtures 'artifacts list-deploy-groups --to terp --version R.3.0.2506+20250721162706.810 --output json --non-interactive'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'list-deploy-groups'
  assert equal $payload.data.raw.0.name 'All'
}

def test-produce-non-interactive [] {
  let result = run-artifact 'artifacts produce --output json --non-interactive'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'MUTATION_NOT_CONFIRMED'
}

def test-consume-dry-run-missing-version [] {
  let result = run-artifact 'artifacts consume --to terp --dest-env DEV --output json --non-interactive --dry-run'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'INTERACTION_REQUIRED'
  assert equal $payload.error.details.required.0 'version'
}

def test-deploy-dry-run-missing-version [] {
  let result = run-artifact 'artifacts deploy --to terp --dest-env DEV --output json --non-interactive --dry-run'
  assert equal $result.exit_code 6
  let payload = parse-json $result.stdout
  assert equal $payload.success false
  assert equal $payload.error.code 'INTERACTION_REQUIRED'
  assert equal $payload.error.details.required.0 'version'
}

def test-deploy-dry-run [] {
  let result = run-artifact 'artifacts deploy --to terp --dest-env DEV --version R.3.0.2506+20250721162706.810 --output json --non-interactive --dry-run'
  assert equal $result.exit_code 0
  let payload = parse-json $result.stdout
  assert equal $payload.success true
  assert equal $payload.action 'deploy'
  assert equal $payload.data.dryRun true
  assert equal $payload.data.version 'R.3.0.2506+20250721162706.810'
  assert equal $payload.data.destinationProjectId 1000215
}
