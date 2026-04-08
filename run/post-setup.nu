#!/usr/bin/env nu
# Author: hustcer
# Created: 2026/03/31 15:39:56
# Description: Complete post-install configuration for termix-nu on macOS/Linux.

const alias_begin = '# >>> termix-nu alias >>>'
const alias_end = '# <<< termix-nu alias <<<'
const auto_detect_shells = [bash zsh fish nu sh]
const shell_configs = {
  bash: {
    file: '.bashrc',
    alias: "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t='
  },
  zsh: {
    file: '.zshrc',
    alias: "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t='
  },
  sh: {
    file: '.profile',
    alias: "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t='
  },
  # NOTE: ksh, csh, and tcsh are not auto-detected; only used when explicitly specified via --shells
  ksh: {
    file: '.kshrc',
    alias: "alias t='just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t='
  },
  fish: {
    file: '.config/fish/config.fish',
    alias: 'alias t "just --justfile ~/.justfile --dotenv-path ~/.env --working-directory ."',
    conflict: '(?m)^alias\\s+t\\s+'
  },
  nu: {
    alias: 'alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .',
    conflict: '(?m)^alias\\s+t\\s*='
  },
  csh: {
    file: '.cshrc',
    alias: "alias t 'just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t\\s+'
  },
  tcsh: {
    file: '.tcshrc',
    alias: "alias t 'just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .'",
    conflict: '(?m)^alias\\s+t\\s+'
  },
}

def normalize-path [path: string] {
  $path | path expand
}

def absolute-path? [path: string] {
  let is_posix_absolute = $path | str starts-with '/'
  let is_windows_drive_absolute = $path =~ r#'^[A-Za-z]:[\\/]'#
  let is_unc_absolute = $path | str starts-with '\\\\'

  $is_posix_absolute or $is_windows_drive_absolute or $is_unc_absolute
}

def ensure-termix-root [termix_dir: string] {
  let required = [Justfile termix.toml .env-example .termixrc-example]
  let missing = $required
    | where {|name| not (([$termix_dir $name] | path join) | path exists) }

  if ($missing | is-not-empty) {
    error make { msg: $'Invalid termix-nu directory: missing ($missing | str join ", ") in ($termix_dir)' }
  }
}

def is-under-dir [candidate: string, root: string] {
  let candidate = normalize-path $candidate
  let root = normalize-path $root
  try {
    let relative = $candidate | path relative-to $root
    let head = $relative | path split | first
    $relative == '.' or $head != '..'
  } catch {
    false
  }
}

def resolve-link-target [link_path: string] {
  let raw_target = try { ls -l $link_path | get 0.target } catch { null }
  if ($raw_target | is-empty) {
    return (normalize-path $link_path)
  }
  if (absolute-path? $raw_target) {
    normalize-path $raw_target
  } else {
    normalize-path ([($link_path | path dirname) $raw_target] | path join)
  }
}

def get-path-kind [path: string] {
  let kind = $path | path type
  if $kind == null { return null }
  if $kind == 'symlink' { return 'symlink' }

  let target = try { ls -l $path | get 0.target } catch { null }
  if ($target | is-not-empty) { 'symlink' } else { $kind }
}

def ensure-local-env [termix_dir: string] {
  let env_example = [$termix_dir '.env-example'] | path join
  let env_file = [$termix_dir '.env'] | path join

  if not ($env_file | path exists) {
    cp $env_example $env_file
    print $'Created (ansi g)($env_file)(ansi rst) from .env-example'
  }

  let content = open $env_file --raw
  let line_ending = if ($content | str contains "\r\n") { "\r\n" } else { (char nl) }
  let replacement = $"TERMIX_DIR='($termix_dir)'"
  let has_termix_dir = ($content | lines | any {|line|
    let trimmed = $line | str trim
    $trimmed =~ r#'^(?:export\s+)?TERMIX_DIR\s*='# and not ($trimmed | str starts-with '#')
  })

  let updated = if $has_termix_dir {
    $content | lines | each {|line|
      let trimmed = $line | str trim
      if ($trimmed =~ r#'^(?:export\s+)?TERMIX_DIR\s*='#) and not ($trimmed | str starts-with '#') {
        $replacement
      } else {
        $line
      }
    } | str join $line_ending
  } else if ($content | str trim | is-empty) {
    $replacement
  } else {
    [($content | str replace -r r#'(\r?\n)+$'# '') '' $replacement] | str join $line_ending
  }

  let final = if ($updated | str ends-with $line_ending) { $updated } else { $updated + $line_ending }
  $final | save -f $env_file
  print $'Updated (ansi g)TERMIX_DIR(ansi rst) in (ansi g)($env_file)(ansi rst)'
}

def ensure-local-termixrc [termix_dir: string] {
  let example_file = [$termix_dir '.termixrc-example'] | path join
  let target_file = [$termix_dir '.termixrc'] | path join

  if not ($target_file | path exists) {
    cp $example_file $target_file
    print $'Created (ansi g)($target_file)(ansi rst) from .termixrc-example'
  }
}

def ensure-link [source: string, dest: string, termix_dir: string] {
  let source = normalize-path $source
  let dest_type = get-path-kind $dest

  match $dest_type {
    null => {
      ln -s $source $dest
      print $'Created symlink (ansi g)($dest)(ansi rst) -> (ansi g)($source)(ansi rst)'
    }
    symlink => {
      let target = resolve-link-target $dest
      if (is-under-dir $target $termix_dir) {
        print $'Reusing existing termix symlink (ansi g)($dest)(ansi rst) -> (ansi g)($target)(ansi rst)'
      } else {
        error make { msg: $'Refusing to overwrite symlink ($dest) -> ($target), it does not point into ($termix_dir)' }
      }
    }
    file => {
      print $'Keeping existing file (ansi y)($dest)(ansi rst), skip creating symlink'
    }
    _ => {
      error make { msg: $'Unsupported existing path type at ($dest): ($dest_type)' }
    }
  }
}

def ensure-exact-link [source: string, dest: string] {
  let source = normalize-path $source
  let dest_type = get-path-kind $dest

  match $dest_type {
    null => {
      ln -s $source $dest
      print $'Created symlink (ansi g)($dest)(ansi rst) -> (ansi g)($source)(ansi rst)'
    }
    symlink => {
      let target = resolve-link-target $dest
      if (normalize-path $target) == $source {
        print $'Reusing existing symlink (ansi g)($dest)(ansi rst) -> (ansi g)($target)(ansi rst)'
      } else {
        error make { msg: $'Refusing to overwrite symlink ($dest) -> ($target), expected ($source)' }
      }
    }
    _ => {
      error make { msg: $'Refusing to overwrite existing path at ($dest): expected symlink to ($source)' }
    }
  }
}

def ensure-skill-links [termix_dir: string, home_dir: string] {
  let skills_dir = [$termix_dir skills] | path join
  if not ($skills_dir | path exists) {
    print $'No local skills directory found at (ansi y)($skills_dir)(ansi rst), skip skill installation'
    return
  }

  let skill_dirs = ls $skills_dir
    | where type == dir
    | get name
    | each {|path| $path | path expand }
  let install_roots = [
    ([$home_dir '.agents/skills'] | path join)
    ([$home_dir '.claude/skills'] | path join)
  ]

  for install_root in $install_roots {
    if not ($install_root | path exists) {
      mkdir $install_root
    }
  }

  for skill_dir in $skill_dirs {
    let skill_name = $skill_dir | path basename
    for install_root in $install_roots {
      ensure-exact-link $skill_dir ([$install_root $skill_name] | path join)
    }
  }
}

def strip-managed-block [content: string] {
  mut lines_out = []
  mut inside_block = false

  for line in ($content | lines) {
    if $line == $alias_begin {
      $inside_block = true
      continue
    }
    if $line == $alias_end {
      $inside_block = false
      continue
    }
    if not $inside_block {
      $lines_out = ($lines_out | append $line)
    }
  }

  $lines_out | str join (char nl)
}

def build-managed-prefix [content: string] {
  let base = $content | str replace -r r#'(\r?\n)+$'# ''
  if ($base | str trim | is-empty) { '' } else { $base + (char nl) + (char nl) }
}

def ensure-alias-block [
  shell_name: string,
  home_dir: string,
  nu_config_path?: string,
] {
  let spec = $shell_configs | get $shell_name
  let config_path = if $shell_name == 'nu' {
    if ($nu_config_path | is-not-empty) {
      normalize-path $nu_config_path
    } else {
      [$home_dir '.config/nushell/config.nu'] | path join
    }
  } else {
    [$home_dir $spec.file] | path join
  }
  let config_dir = $config_path | path dirname
  let alias_line = $spec.alias
  let managed_block = [$alias_begin $alias_line $alias_end ''] | str join (char nl)

  if not ($config_dir | path exists) {
    mkdir $config_dir
  }

  let current = if ($config_path | path exists) { open $config_path --raw } else { '' }
  let stripped = strip-managed-block $current
  let has_exact_alias_line = ($stripped | lines | any {|line| $line == $alias_line })

  if $has_exact_alias_line {
    # Alias line already exists as bare text; move it into managed block for future management
    let cleaned = $stripped | lines | where {|l| $l != $alias_line } | str join (char nl)
    let has_conflict_alias = ($cleaned | lines | any {|line|
      let trimmed = $line | str trim
      not ($trimmed | is-empty) and not ($trimmed | str starts-with '#') and ($trimmed | str starts-with 'alias t')
    })
    if $has_conflict_alias {
      error make { msg: $'Found existing `t` alias in ($config_path), please reconcile it manually before re-running post-setup' }
    }
    let prefix = build-managed-prefix $cleaned
    ($prefix + $managed_block) | save -f $config_path
    print $'Configured alias for (ansi g)($shell_name)(ansi rst) in (ansi g)($config_path)(ansi rst)'
  } else if ($stripped !~ $spec.conflict) {
    # No conflicting alias found; append managed block
    let prefix = build-managed-prefix $stripped
    ($prefix + $managed_block) | save -f $config_path
    print $'Configured alias for (ansi g)($shell_name)(ansi rst) in (ansi g)($config_path)(ansi rst)'
  } else {
    error make { msg: $'Found existing `t` alias in ($config_path), please reconcile it manually before re-running post-setup' }
  }
}

def detect-shells [] {
  let shells_from_file = if ('/etc/shells' | path exists) {
    open /etc/shells --raw
      | lines
      | str trim
      | where {|line| ($line | is-not-empty) and not ($line | str starts-with '#') }
      | each {|line| $line | path basename }
  } else {
    []
  }
  let active_shell = $env | get -o SHELL | default '' | path basename

  $auto_detect_shells
    | where {|shell_name|
      ($shell_name in $shells_from_file) or ($shell_name == $active_shell) or ((try { which $shell_name | length } catch { 0 }) > 0)
    }
}

export def run-post-setup [
  termix_dir: string = '.',
  --home-dir: string = $nu.home-dir,
  --nu-config-path: string = $nu.config-path,
  --shells: string,
] {
  let termix_dir = normalize-path $termix_dir
  let home_dir = normalize-path $home_dir
  let nu_config_path = if ($nu_config_path | is-not-empty) {
    normalize-path $nu_config_path
  } else {
    ''
  }
  let selected_shells = if ($shells | is-not-empty) {
    $shells | split row ',' | each { str trim } | compact -e
  } else {
    detect-shells
  }
  let supported = $shell_configs | columns
  let unsupported = $selected_shells | where {|shell_name| $shell_name not-in $supported }

  ensure-termix-root $termix_dir
  if not ($home_dir | path exists) {
    mkdir $home_dir
  }

  if ($unsupported | is-not-empty) {
    error make { msg: $'Unsupported shells: ($unsupported | str join ", ")' }
  }

  print 'Running termix-nu post setup ...'
  ensure-local-env $termix_dir
  ensure-local-termixrc $termix_dir
  ensure-link ([$termix_dir '.env'] | path join) ([$home_dir '.env'] | path join) $termix_dir
  ensure-link ([$termix_dir 'Justfile'] | path join) ([$home_dir '.justfile'] | path join) $termix_dir
  ensure-skill-links $termix_dir $home_dir

  for shell_name in $selected_shells {
    ensure-alias-block $shell_name $home_dir $nu_config_path
  }

  print $'(ansi g)Post setup completed successfully.(ansi rst)'
}

def main [
  termix_dir: string = '.',
  --home-dir: string = $nu.home-dir,
  --nu-config-path: string = $nu.config-path,
  --shells: string,
] {
  run-post-setup $termix_dir --home-dir=$home_dir --nu-config-path=$nu_config_path --shells=$shells
}
