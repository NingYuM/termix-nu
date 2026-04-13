#!/usr/bin/env nu
# Description:
#   Unit tests for ERDA env fallback behavior
# Usage:
#   nu tests/test-erda.nu

use std assert
use utils.nu [run_tests]

def main [] {
  run_tests $env.PROCESS_PATH [
    { name: 'check-erda-envs loads credentials from .env', execute: { test-check-erda-envs-loads-from-dotenv } }
    { name: 'check-erda-envs preserves existing environment values', execute: { test-check-erda-envs-keeps-existing-env } }
  ]
}

def repo-root [] {
  ([$env.FILE_PWD '..'] | path join | path expand)
}

def make-temp-home [] {
  let tmp_dir = ($env.TMPDIR? | default ($env.TEMP? | default ($env.TMP? | default '/tmp')))
  let dir = [$tmp_dir $"termix-erda-test-(random int)"] | path join
  mkdir $dir
  '{}' | save ([$dir '.termix-conf'] | path join)
  $dir
}

def run-check-erda-envs [termix_dir: string, username: string, password: string] {
  let erda_module = ([(repo-root) utils erda.nu] | path join)
  let command = [
    $'use ($erda_module) [check-erda-envs]',
    'check-erda-envs',
    '[$env.ERDA_USERNAME $env.ERDA_PASSWORD] | str join "|" | print',
  ] | str join '; '
  with-env {
    TERMIX_DIR: $termix_dir,
    ERDA_USERNAME: $username,
    ERDA_PASSWORD: $password,
  } {
    nu -c $command | complete
  }
}

def test-check-erda-envs-loads-from-dotenv [] {
  let home = make-temp-home
  "ERDA_USERNAME=dotenv-user\nERDA_PASSWORD=dotenv-pass\n" | save ([$home '.env'] | path join)

  let result = run-check-erda-envs $home '' ''
  assert equal $result.exit_code 0
  assert equal (($result.stdout | str trim | str contains 'dotenv-user|dotenv-pass')) true
}

def test-check-erda-envs-keeps-existing-env [] {
  let home = make-temp-home
  "ERDA_USERNAME=dotenv-user\nERDA_PASSWORD=dotenv-pass\n" | save ([$home '.env'] | path join)

  let result = run-check-erda-envs $home existing-user existing-pass
  assert equal $result.exit_code 0
  assert equal (($result.stdout | str trim | str contains 'existing-user|existing-pass')) true
}
