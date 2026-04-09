#!/usr/bin/env nu
# Description:
#   Unit tests for run/post-setup.nu
# Usage:
#   nu tests/test-post-setup.nu

use std assert
use utils.nu [run_tests]
use ../run/post-setup.nu [install-local-skills, run-post-setup]

def main [] {
  let common_tests = [
    { name: 'install-local-skills is idempotent', execute: { test-install-local-skills-idempotent } }
    { name: 'install-local-skills removes stale managed links', execute: { test-install-local-skills-removes-stale-managed-links } }
    { name: 'install-local-skills keeps foreign links', execute: { test-install-local-skills-keeps-foreign-links } }
    { name: 'post-setup initializes .termixrc', execute: { test-post-setup-initializes-termixrc } }
    { name: 'post-setup keeps env idempotent', execute: { test-post-setup-env-idempotent } }
    { name: 'post-setup preserves env line endings', execute: { test-post-setup-preserves-env-line-endings } }
    { name: 'post-setup is idempotent for aliases', execute: { test-post-setup-idempotent } }
    { name: 'post-setup errors on mixed alias conflict', execute: { test-post-setup-errors-on-mixed-alias-conflict } }
    { name: 'post-setup preserves existing home files', execute: { test-post-setup-preserves-home-files } }
  ]
  let tests = if $nu.os-info.name == 'windows' {
    print 'Skipping symlink-sensitive post-setup tests on Windows'
    $common_tests
  } else {
    [
      { name: 'post-setup initializes env links and aliases', execute: { test-post-setup-initializes } }
      ...$common_tests
      { name: 'post-setup errors on foreign symlink', execute: { test-post-setup-errors-on-foreign-symlink } }
    ]
  }

  run_tests $env.PROCESS_PATH $tests
}

def make-fixture [] {
  let root = (mktemp -d | path expand)
  let termix_dir = [$root termix-nu] | path join
  let home_dir = [$root home] | path join
  let skills_dir = [$termix_dir skills] | path join

  mkdir $termix_dir
  mkdir $home_dir
  mkdir $skills_dir
  'set dotenv-load := true\n' | save ([$termix_dir Justfile] | path join)
  'version = "0.0.0"\n' | save ([$termix_dir termix.toml] | path join)
  "TERMIX_DIR='/Users/terminus/termix-nu'\nDINGTALK_NOTIFY='on'\n" | save ([$termix_dir '.env-example'] | path join)
  "[deploy]\nname = 'demo'\n" | save ([$termix_dir '.termixrc-example'] | path join)
  mkdir ([$skills_dir setup-termix] | path join)
  mkdir ([$skills_dir terp-assets] | path join)
  '# setup-termix\n' | save ([$skills_dir setup-termix SKILL.md] | path join)
  '# terp-assets\n' | save ([$skills_dir terp-assets SKILL.md] | path join)

  {
    root: $root
    termix_dir: $termix_dir
    home_dir: $home_dir
    skills_dir: $skills_dir
  }
}

def cleanup-fixture [fixture: record<root: string, termix_dir: string, home_dir: string, skills_dir: string>] {
  if ($fixture.root | path exists) {
    rm -rf $fixture.root
  }
}

def read-target [path: string] {
  let raw_target = try { ls -l $path | get 0.target } catch { null }
  if ($raw_target | is-empty) {
    $path | path expand
  } else {
    $raw_target | path expand
  }
}

def path-is-link [path: string] {
  let kind = $path | path type
  if $kind == 'symlink' { return true }
  let target = try { ls -l $path | get 0.target } catch { null }
  $target | is-not-empty
}

def normalize-test-path [path: string] {
  let normalized = $path | path expand
  if $nu.os-info.name == 'windows' {
    $normalized | str downcase
  } else {
    $normalized
  }
}

def assert-same-path [left: string, right: string] {
  assert equal (normalize-test-path $left) (normalize-test-path $right)
}

# Run a test closure with automatic fixture setup and cleanup
def with-fixture [test_fn: closure] {
  let fixture = make-fixture
  try {
    do $test_fn $fixture
  } catch {|err|
    cleanup-fixture $fixture
    error make { msg: $err.msg }
  }
  cleanup-fixture $fixture
}

def test-post-setup-initializes [] {
  with-fixture {|fixture|
    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --nu-config-path ([$fixture.home_dir '.config/nushell/config.nu'] | path join) --shells 'bash,zsh,fish,nu,sh'

    let env_file = [$fixture.termix_dir '.env'] | path join
    let env_text = open $env_file --raw
    assert str contains $env_text $"TERMIX_DIR='(($fixture.termix_dir | path expand))'"
    assert equal (($env_text | lines | where {|line| $line =~ r#'^TERMIX_DIR='# } | length)) 1
    assert equal (($env_text | lines | where {|line| $line =~ r#'^TERMIX_DIR=\\\\'# } | length)) 0

    let home_env = [$fixture.home_dir '.env'] | path join
    let home_justfile = [$fixture.home_dir '.justfile'] | path join
    assert equal (path-is-link $home_env) true
    assert equal (path-is-link $home_justfile) true
    assert-same-path (read-target $home_env) ($env_file | path expand)
    assert-same-path (read-target $home_justfile) (([$fixture.termix_dir Justfile] | path join) | path expand)
    assert equal (([$fixture.termix_dir '.termixrc'] | path join) | path exists) true

    for skill_name in [setup-termix terp-assets] {
      let source = [$fixture.skills_dir $skill_name] | path join | path expand
      let agents_dest = [$fixture.home_dir '.agents/skills' $skill_name] | path join
      let claude_dest = [$fixture.home_dir '.claude/skills' $skill_name] | path join

      assert equal (path-is-link $agents_dest) true
      assert equal (path-is-link $claude_dest) true
      assert-same-path (read-target $agents_dest) $source
      assert-same-path (read-target $claude_dest) $source
    }

    let bashrc = [ $fixture.home_dir '.bashrc' ] | path join
    let zshrc = [ $fixture.home_dir '.zshrc' ] | path join
    let fish_conf = [ $fixture.home_dir '.config/fish/config.fish' ] | path join
    let nu_conf = [ $fixture.home_dir '.config/nushell/config.nu' ] | path join
    let profile = [ $fixture.home_dir '.profile' ] | path join

    assert str contains (open $bashrc --raw) "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'"
    assert str contains (open $zshrc --raw) "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'"
    assert str contains (open $fish_conf --raw) 'alias t "just --justfile ~/.justfile --dotenv-path ~/.env --working-directory ."'
    assert str contains (open $nu_conf --raw) 'alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'
    assert str contains (open $profile --raw) "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'"
  }
}

def test-post-setup-initializes-termixrc [] {
  with-fixture {|fixture|
    let target_file = [$fixture.termix_dir '.termixrc'] | path join
    let example_file = [$fixture.termix_dir '.termixrc-example'] | path join
    assert equal ($target_file | path exists) false

    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'

    assert equal ($target_file | path exists) true
    assert equal (open $target_file --raw) (open $example_file --raw)

    "[deploy]\nname = 'custom'\n" | save -f $target_file
    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'
    assert equal (open $target_file --raw) "[deploy]\nname = 'custom'\n"
  }
}

def test-install-local-skills-idempotent [] {
  with-fixture {|fixture|
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir

    for skill_name in [setup-termix terp-assets] {
      let source = [$fixture.skills_dir $skill_name] | path join | path expand
      let agents_dest = [$fixture.home_dir '.agents/skills' $skill_name] | path join
      let claude_dest = [$fixture.home_dir '.claude/skills' $skill_name] | path join

      assert equal (path-is-link $agents_dest) true
      assert equal (path-is-link $claude_dest) true
      assert-same-path (read-target $agents_dest) $source
      assert-same-path (read-target $claude_dest) $source
    }
  }
}

def test-install-local-skills-removes-stale-managed-links [] {
  with-fixture {|fixture|
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir

    rm -rf ([$fixture.skills_dir setup-termix] | path join)
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir

    let removed_agents = [$fixture.home_dir '.agents/skills/setup-termix'] | path join
    let removed_claude = [$fixture.home_dir '.claude/skills/setup-termix'] | path join
    let kept_source = [$fixture.skills_dir terp-assets] | path join | path expand
    let kept_agents = [$fixture.home_dir '.agents/skills/terp-assets'] | path join
    let kept_claude = [$fixture.home_dir '.claude/skills/terp-assets'] | path join

    assert equal ($removed_agents | path exists) false
    assert equal ($removed_claude | path exists) false
    assert equal (path-is-link $kept_agents) true
    assert equal (path-is-link $kept_claude) true
    assert-same-path (read-target $kept_agents) $kept_source
    assert-same-path (read-target $kept_claude) $kept_source
  }
}

def test-install-local-skills-keeps-foreign-links [] {
  with-fixture {|fixture|
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir

    let foreign_dir = [$fixture.root foreign-skills legacy] | path join
    mkdir $foreign_dir
    let foreign_agents = [$fixture.home_dir '.agents/skills/legacy'] | path join
    let foreign_claude = [$fixture.home_dir '.claude/skills/legacy'] | path join
    ln -s $foreign_dir $foreign_agents
    ln -s $foreign_dir $foreign_claude

    rm -rf ([$fixture.skills_dir setup-termix] | path join)
    install-local-skills $fixture.termix_dir --home-dir=$fixture.home_dir

    assert equal (path-is-link $foreign_agents) true
    assert equal (path-is-link $foreign_claude) true
    assert-same-path (read-target $foreign_agents) ($foreign_dir | path expand)
    assert-same-path (read-target $foreign_claude) ($foreign_dir | path expand)
  }
}

def test-post-setup-idempotent [] {
  with-fixture {|fixture|
    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --nu-config-path ([$fixture.home_dir '.config/nushell/config.nu'] | path join) --shells 'bash,nu'
    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --nu-config-path ([$fixture.home_dir '.config/nushell/config.nu'] | path join) --shells 'bash,nu'

    let bashrc = open ([$fixture.home_dir '.bashrc'] | path join) --raw
    let nu_conf = open ([$fixture.home_dir '.config/nushell/config.nu'] | path join) --raw

    assert equal (($bashrc | lines | where {|line| $line == '# >>> termix-nu alias >>>' } | length)) 1
    assert equal (($bashrc | lines | where {|line| $line =~ '^alias t=' } | length)) 1
    assert equal (($nu_conf | lines | where {|line| $line == '# >>> termix-nu alias >>>' } | length)) 1
    assert equal (($nu_conf | lines | where {|line| $line == 'alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .' } | length)) 1
    assert equal (($nu_conf | str contains "\n\n\n# >>> termix-nu alias >>>") ) false

    for skill_name in [setup-termix terp-assets] {
      let source = [$fixture.skills_dir $skill_name] | path join | path expand
      let agents_dest = [$fixture.home_dir '.agents/skills' $skill_name] | path join
      let claude_dest = [$fixture.home_dir '.claude/skills' $skill_name] | path join

      assert equal (path-is-link $agents_dest) true
      assert equal (path-is-link $claude_dest) true
      assert-same-path (read-target $agents_dest) $source
      assert-same-path (read-target $claude_dest) $source
    }
  }
}

def test-post-setup-env-idempotent [] {
  with-fixture {|fixture|
    "TERMIX_DIR=\"/tmp/wrong\"\nOTHER=1\n" | save -f ([$fixture.termix_dir '.env'] | path join)

    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'
    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'

    let env_text = open ([$fixture.termix_dir '.env'] | path join) --raw

    assert equal (($env_text | lines | where {|line| $line | str starts-with 'TERMIX_DIR=' } | length)) 1
    assert equal (($env_text | str contains '/tmp/wrong')) false
    assert equal (($env_text | lines | where {|line| $line | str starts-with 'TERMIX_DIR=\\' } | length)) 0
    assert str contains $env_text 'OTHER=1'
  }
}

def test-post-setup-preserves-env-line-endings [] {
  with-fixture {|fixture|
    let env_file = [$fixture.termix_dir '.env'] | path join
    "FOO=1\r\nBAR=2\r\n" | save -rf $env_file

    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'

    let env_hex = open $env_file --raw | encode hex
    assert equal ($env_hex | str contains '0D0A5445524D49585F4449523D') true
    assert equal ($env_hex | str contains '0D0A0D0A5445524D49585F4449523D') true
    assert equal ($env_hex | str contains '0A0A5445524D49585F4449523D') false
  }
}

def test-post-setup-errors-on-mixed-alias-conflict [] {
  with-fixture {|fixture|
    let bashrc = [$fixture.home_dir '.bashrc'] | path join
    "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'\nalias t='other command'\n" | save $bashrc

    let failed = try {
      run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'
      false
    } catch {
      true
    }

    assert equal $failed true
    assert equal ((open $bashrc --raw) | str contains "# >>> termix-nu alias >>>") false
  }
}

def test-post-setup-preserves-home-files [] {
  with-fixture {|fixture|
    let home_env = [$fixture.home_dir '.env'] | path join
    let home_justfile = [$fixture.home_dir '.justfile'] | path join
    'CUSTOM_HOME_ENV=1\n' | save $home_env
    'default:\n\t@echo home\n' | save $home_justfile

    run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'

    assert equal ($home_env | path type) 'file'
    assert equal ($home_justfile | path type) 'file'
    assert str contains (open $home_env --raw) 'CUSTOM_HOME_ENV=1'
    assert str contains (open $home_justfile --raw) '@echo home'
  }
}

def test-post-setup-errors-on-foreign-symlink [] {
  with-fixture {|fixture|
    let foreign_dir = [$fixture.root foreign] | path join
    mkdir $foreign_dir
    let foreign_env = [$foreign_dir '.env'] | path join
    'TERMIX_DIR=/tmp/elsewhere\n' | save $foreign_env
    ln -s $foreign_env ([$fixture.home_dir '.env'] | path join)

    let failed = try {
      run-post-setup $fixture.termix_dir --home-dir $fixture.home_dir --shells 'bash'
      false
    } catch {
      true
    }

    assert equal $failed true
  }
}
