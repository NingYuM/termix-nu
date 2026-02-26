# Nushell Config File
# Update config from: 919d55f3f
# version = 0.100.0

# source ~/.config/nushell/config.nu
# Ref:
#   1. https://ohmyposh.dev/docs/themes
#   2. https://github.com/nushell/nushell/issues/4300 Config Settings
#   3. https://github.com/nushell/nushell/blob/main/docs/How_To_Coloring_and_Theming.md

use std [repeat]

# use ~/github/terminus/termix-nu/run/zoxide-eq.nu [z, zi]
source $'($nu.home-dir)/.zoxide.nu'

# ---------------------- Aliases -------------------------
# List files and display one entry per line with `eza`
alias ll = eza -l
# List all files (including hidden files) with `eza`
alias la = eza -la
# Change to parent directory
alias .. = cd ..
# Change to parent of parent directory
alias ... = do { cd ..; cd .. }
# Global `just` task receipes
alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .
alias cr = nu /Users/hustcer/iWork/terminus/deepseek-review/cr --config /Users/hustcer/iWork/terminus/deepseek-review/config.yml
# Show Nushell commands
alias nuc = print (
  help commands | where command_type != custom and command_type != alias
    | default '' decl_id
    | default '' signatures
    | reject signatures search_terms decl_id
)
# Show the count of Nushell commands
alias nucc = print (help commands | where command_type != custom and command_type != alias | length)
alias tokeid = print (
  tokei
    | lines
    | skip 1
    | str join "\n"
    | detect columns
    | where {|it| $it.Language !~ "=" and $it.Language !~ "-" and (not ($it.Files | is-empty)) }
    | into int Files Lines Code Comments Blanks
)

# -------------------- Custom Commands -------------------------
def isWindows [] { (sys host | get name) == 'Windows' }

# Show the count of Nushell commands
def action [action?: string, --list(-l)] {
  const actionMap = {
    produce: 'Create artifacts from CLI',
    deploy: 'Deploy artifacts to the specified environment of destination project:'
    consume: 'Consume the artifacts provided by the producer:'
  }
  if $list { print ($actionMap | columns | str join ', '); return }
  mut counter = 0
  let chars = $actionMap | get -o $action | default 'Unknown Action' | split row ''
  let total = $chars | length
  loop {
    if $counter == $total { break }
    print -n ($chars | get $counter); sleep 0.1sec; $counter += 1
  }
}

# Clear screen
def cls [] { ansi cls }
def 'env exists?' [] { $in in (env).name }  # ' Just hack for syntax highlight
# Sum input numbers
def sum [] { reduce {|acc, item| $acc + $item } }
# Display Nu version info in markdown format
def ver [] { (version | transpose key value | to md --pretty) }

def kq [] { do -i { ps | where name == xbar | get 0 | kill -f $in.pid } }

def --env yy [...args] {
  let tmp = (mktemp -t "yazi-cwd.XXXXX")
  yazi ...$args --cwd-file $tmp
  let cwd = (open $tmp)
  if $cwd != "" and $cwd != $env.PWD {
    cd $cwd
  }
  rm -fp $tmp
}

def q-deps [] {
  $env.config.table.mode = 'psql'
  [setup-moonbit deepseek-review milestone-action setup-nu]
    | each {|it|
      let html = http get $'https://github.com/hustcer/($it)/network/dependents'
      print -n (char nl)
      let count = $html | query web --query '#dependents a.selected' | get 0.3 | str trim | lines | first
      print $'($it) (ansi g)($count)(ansi rst) deps:'
      print $'(ansi g)-------------------------(ansi rst)'
      $html
        | query web --query '#dependents a[data-hovercard-url]'
        | each { get 0 }
        | window 2 -s 2
        | each {|r| $'($r.0)/($r.1)' }
        | print
    } | ignore
}

# Ask anything from DeepSeek R1
def ds-ask [msg: string, --top-p(-p): float = 1.0, --temperature(-t): float = 0.8] {
  let API_URL = 'http://aihc.hz.hustcer.com:50006/api/chat-process'
  let message = if ($msg | is-empty) { $in } else { $msg }
  let args = {
      top_p: $top_p,
      prompt: $message,
      temperature: $temperature,
      systemMessage: 'You are a helpful assistant.',
    }
  http post --content-type application/json $API_URL $args
    | lines
    | each {|line| $line | from json | get delta | print -n }
}

# Checkout branch by fzf
def gco [branch?: string] {
  if ($branch | is-not-empty) {
    git checkout $branch; return
  }
  let branch = git branch
    | lines
    | par-each -k { str substring 2.. }
    | sort
    | to text
    | fzf --height 30% --layout=reverse --highlight-line
    | complete
    | get stdout
    | str trim

  if ($branch | is-not-empty) {
    git checkout $branch
  }
}

# Get help on commands using fzf
def 'get help' [] {
  do {
    # doesn't work well with nushell due to escaping issues. if you use nushell
    # as your login shell, you can set SHELL env var to an alternative shell
    # temporarily like zsh below, and it will still work.
    # $env.SHELL = /bin/zsh
    help commands | where command_type == built-in
    | each {|c|
      let search_terms = if ($c.search_terms == "") {""} else {$"\(($c.search_terms))"}
      let category = if ($c.category == "") {""} else {$"\(Category: ($c.category))"}
      $"(ansi default)($c.name?):(ansi light_blue) ($c.description?) (ansi cyan)($search_terms) ($category)(ansi rst)" }
    | to text
    | fzf --ansi --tiebreak=begin,end,chunk --exact --preview="echo -n {} | nu --stdin -c 'help ($in | parse \"{c}:{u}\" | get c.0)'" --bind 'ctrl-/:change-preview-window(right,70%|right)'
  }
}

# Print a horizontal line
export def hr-line [
  width?: int = 90,
  --color(-c): string = 'g',
  --blank-line(-b),
  --with-arrow(-a),
] {
  print $'(ansi $color)('─' | repeat $width | str join)(if $with_arrow {'>'})(ansi rst)'
  if $blank_line { char nl }
}

# Reload Nushell Config by setting `RELOAD_NU` environment variable
export def --env rc [] {
  $env.RELOAD_NU = true
}

# Display my IP info
def get-ip [] {
  $env.config.table.mode = 'basic'
  # curl ifconfig.me
  # curl api.ipify.org
  # curl ipinfo.io/ip
  http get https://lumtest.com/myip.json | table -e
}

# Update all local branches for the specified repos
def ua [] {
  let repos = [
    'terp-ui',
    'nusi-slim',
    'nusi-flex',
    'terp-docs',
    'termix-nu',
    'setup-nu',
    'setup-moonbit',
  ]
  for p in $repos {
    z $p;
    print $'Pull all from (ansi p)($env.PWD)(ansi rst):'
    hr-line; t pull-all; print (char nl)
  }
}

# Clean nightly Tags:
# `git tag -l | lines | where { $in =~ nightly } | each { git tag -d $in }`
# Show Nu nightly builds information
def nun [] {
  let current = nu --version
  let headers = if ($env.GITHUB_TOKEN? | is-empty) { [] } else { [Authorization $'Bearer ($env.GITHUB_TOKEN)'] }
  let nightly = http get -H $headers https://api.github.com/repos/nushell/nightly/releases
    | sort-by -r created_at
    | select name created_at assets.name.0
  let match = $nightly | where name =~ $current
  print $'Current version:'; hr-line
  $match | into record
    | upsert hash {|it| $it.name | split row + | last }
    | upsert version $current
    | select version hash created_at name 'assets.name.0'
    | print

  print $'(char nl)All nightly versions:'
  $nightly | print
}

# Pretty print the OSS list from oss-index
def pretty-oss [
  name?: string,      # The name of the Object to show details
  --sort-by(-s): string = 'modified',  # sort-by: 'modified' | 'size' | 'name'
] {
  const TIME_FMT = '%Y/%m/%d %H:%M:%S'
  def empty-to-dot [] { if ($in | is-empty) { '.' } else { $in } }
  def oname-to-url [] {
    let bucket = $env.OSS_BUCKET? | default terminus-new-trantor
    let domainSuffix = $env.OSS_ENDPOINT? | default https://oss-cn-hangzhou.aliyuncs.com | str replace https:// ''
    $in | str replace oss://($bucket) https://($bucket).($domainSuffix)
  }

  let raw  = $in | detect columns --guess
      | drop 2 | select LastModifiedTime 'Size(B)' ObjectName
      | upsert LastModifiedTime { str replace ' CST' '' | into datetime | format date $TIME_FMT }
      | rename -c { 'Size(B)': 'size', LastModifiedTime: 'modified', ObjectName: 'oname' }
      | upsert size { into filesize }
      | upsert name {|it| $it.oname | split row '/' | last | empty-to-dot }

  let path = $raw | sort-by oname | first
  let totalSize = $raw | reduce -f 0mb {|it, acc| $it.size + $acc }
  print $'(char nl)Total Size: (ansi p)($totalSize)(ansi rst) of (ansi p)($path.oname)(ansi rst)'; hr-line
  $raw
      | select name size modified
      | sort-by -r ([$sort_by] | into cell-path)
      | print

  if ($name | is-not-empty) {
    print $'(char nl)Details of (ansi p)($name)(ansi rst):'; hr-line
    $raw | where name == $name
      | select name oname size modified
      | upsert url {|it| $it.oname | oname-to-url }
      | each { print; hr-line -c grey66 }
  }
}

# 在本地构建并安装所有 Nushell 二进制文件
def nu-install-all [
  --plugin-only,  # Install plugins only
] {
  if not ((pwd | path basename | str trim) == 'nushell') { z nushell }
  print 'Remove cached shadow files...'
  fd -I shadow.rs | lines | each { |it| rm $it } | flatten
  print (fd -I shadow.rs )

  let nu_root = $env.PWD
  print $'Run install all in ($nu_root)'

  print '-------------------------------------------------------------------'
  print 'Installing Nu with dataframes,extra and all the plugins'
  print '-------------------------------------------------------------------'

  def install-nushell [] {
    print $'(char nl)Installing Nushell'
    print '----------------------------'

    cd $nu_root
    cargo install --force --locked --path .
  }

  if not $plugin_only { install-nushell }

  def install-plugin [] {
    let plugin = $in

    print $'(char nl)Installing ($plugin)'
    print '----------------------------'

    cd $'($nu_root)/crates/($plugin)'
    cargo install --force --path .
  }

  let plugins = [
    nu_plugin_inc,
    nu_plugin_gstat,
    nu_plugin_query,
    nu_plugin_polars,
    nu_plugin_formats,
    nu_plugin_example,
    nu_plugin_custom_values,
  ]

  for plugin in $plugins {
    $plugin | install-plugin
  }
}

def cargo-ta  [] { cargo test --all --all-features }

# 备份本地通过 Cargo 安装的 Nu 二进制文件到 ~/Applications/nu-main
def nu-backup-main [] { cp -r ~/.cargo/bin/nu* ~/Applications/nu-main/ }
# 将 ~/Applications/nu-main 中的 Nu 二进制文件恢复到本地 Cargo 安装目录
def nu-restore-main [] { cp -r ~/Applications/nu-main/* ~/.cargo/bin/; print $'Please restart Nu session...' }
# 将 ~/Applications/nu-latest/ 中的 Nu 二进制文件恢复到本地 Cargo 安装目录
def nu-use-latest [] { cp -r ~/Applications/nu-latest/* ~/.cargo/bin/; print $'Please restart Nu session...' }
# 将 ~/Applications/nu-nightly/ 中的 Nu 二进制文件恢复到本地 Cargo 安装目录
def nu-use-nightly [] { cp -r ~/Applications/nu-nightly/* ~/.cargo/bin/; print $'Please restart Nu session...' }
# 将官方发布的最新版 Nu 二进制文件下载到本地并安装到 ~/Applications/nu-latest/ 目录
def nu-fetch-latest [] {
  cd ~/Applications/nu-latest/
  curl -s https://api.github.com/repos/nushell/nushell/releases/latest
    | grep browser_download_url
    | cut -d '"' -f 4
    | grep $'($nu.os-info.arch)-apple-darwin'
    | aria2c -i -
  mkdir nu-latest; tar xvf nu-*.tar.gz --directory=nu-latest
  cp -r nu-latest/**/* .; rm -rf nu-*
  print $'(char nl)Update to Nu: (ansi g)(./nu --version)(ansi rst)'
}

# 将每日構建发布的最新版 Nu 二进制文件下载到本地并安装到 ~/Applications/nu-nightly/ 目录
def nu-fetch-nightly [] {
  cd ~/Applications/nu-nightly
  http get https://api.github.com/repos/nushell/nightly/releases
    | sort-by -r published_at
    | select tag_name name published_at assets_url assets
    | first
    | get assets
    | get browser_download_url
    | where { $in =~ $'($nu.os-info.arch)-apple-darwin' }
    | get 0
    | aria2c -i -
  mkdir nu-nightly; tar xvf nu-*.tar.gz --directory=nu-nightly
  cp -r nu-nightly/**/* .; rm -rf nu-*
  print $'(char nl)Update to Nu: (ansi g)(./nu --version)(ansi rst)'
}

# Show Nu changed configs
def nu-cc [] {
  let defaults = nu -n -c "$env.config = {}; $env.config | reject color_config keybindings menus | to nuon" | from nuon | transpose key default
  let current = $env.config | reject color_config keybindings menus | transpose key current
  $current | merge $defaults | where $it.current != $it.default
}

def cargo-clippy [] {
  cargo clippy --all --all-features -- -D warnings -D clippy::unwrap_used -A clippy::needless_collect
}

# Modify the latest commit's commit date to now
def gtouch [] {
  let now = date now | format date '%Y-%m-%dT%H:%M:%S'
  GIT_COMMITTER_DATE=$now git commit --amend --no-edit --date $now
}

# Example usage: `$nu.config-path | goto`
def --env goto [] {
  let input = $in
  let path = if ($input | path type) == file { ($input | path dirname) } else { $input }
  cd $path
}

# Bump Nushell to new version
def bump-ver [
  --minor(-m)   # Bump minor version
] {
  let fromVer = (open cargo.toml | get package.version)
  let $toVer = if $minor {
    let to = ($fromVer | inc --minor)
    # Reset patch version after bump minor version
    ($to | split row '.' | first 2 | append 0 | str join '.')
  } else {
    $fromVer | inc --patch
  }
  sd -f e -s $fromVer $toVer (fd --type file | lines)
}

# Create a symlink for the specified file
export def symlink [
  existing: path   # The existing file
  link_name: path  # The name of the symlink
] {
  let existing = ($existing | path expand -s)
  let link_name = ($link_name | path expand)

  if $nu.os-info.family == 'windows' {
    if ($existing | path type) == 'dir' {
      mklink /D $link_name $existing
    } else {
      mklink $link_name $existing
    }
  } else {
    ln -s $existing $link_name | ignore
  }
}

# Uppack archive file
export def unpack [
  p: path           # archive to unpack
  --create-dir(-d)  # create a directory
] {
  if $create_dir {
    let dir = ($p | path parse).stem

    if ($p | str ends-with '.tar') {
      mkdir $dir
      tar -xf $p --directory $dir
    } else if ($p | str ends-with '.tar.gz') {
      let dir = ($p | path parse -e 'tar.gz').stem
      mkdir $dir
      tar -xzf $p --directory $dir
    } else if ($p | str ends-with '.tar.xz') {
      let dir = ($p | path parse -e 'tar.xz').stem
      mkdir $dir
      tar -xf $p --directory $dir
    } else if ($p | str ends-with '.tgz') {
      mkdir $dir
      tar zxvf $p --directory $dir
    } else if ($p | str ends-with '.zip') {
      mkdir $dir
      unzip $p -d $dir
    } else if ($p | str ends-with '.7z') {
      mkdir $dir
      ^7z x $p $'-o($dir)'
    } else {
      print $"Unknown extension: ($p)"
    }

  } else {

    if ($p | str ends-with '.tar') {
      tar -xf $p
    } else if ($p | str ends-with '.tar.gz') {
      tar -xzf $p
    } else if ($p | str ends-with '.tar.xz') {
      tar -xf $p
    } else if ($p | str ends-with '.tgz') {
      tar zxvf $p
    } else if ($p | str ends-with '.zip') {
      unzip $p
    } else if ($p | str ends-with '.7z') {
      ^7z x $p
    } else {
      print $"Unknown extension: ($p)"
    }
  }
}

# Watch command output and display it in a table
def monitor [
  command: closure
  --duration (-d): duration = 1sec
] {
  generate {|i=true| sleep $duration; {out: (do $command | table), next: true} }
    | flatten
    | each { clear; $in }
}

def gh-pr [repo: string = 'nushell/nushell'] {
  gh -R $repo pr list --json url,number,author,title
    | from json
    | each { |i| $"- [($i.number)]\(($i.url)\) ($i.title) \(@($i.author.login)\)" }
    | reverse
}

# Show top files by size in current git repo of current directory
def topf [n: int = 20] {
  git ls-files
    | lines
    | each {|it| {name: $it, size: (ls $it | get size | get 0) } }
    | sort-by size -r
    | first $n
}

# load environment variables from the .envrc file.
def --env load-direnv [] {
  load-env (
    open --raw .envrc
      | lines
      | where $it =~ 'export'
      | parse 'export {key}={value}'
      | reduce -f {} { |it, acc| $acc | insert $it.key ($it.value | str trim -c '"') }  # "
  )
}

# Converts a .env file into a record
# May be used like this: open .env | load-env
# Works with quoted and unquoted .env files
export def "from env" []: string -> record {
  let input = $in

  # Process escape sequences in double-quoted values using regex with closure
  let process_escapes = {|content: string|
    $content | str replace -a -r '\\(.)' {|c|
      match $c {
        'n' => (char nl),
        'r' => (char cr),
        't' => (char tab),
        _ => $c
      }
    }
  }

  # Parse double-quoted value with escape sequence support
  let parse_double_quoted = {|val: string|
    let matched = ($val | parse -r '^"(?P<content>(?:[^"\\]|\\.)*)"')
    if ($matched | is-empty) { $val | str trim -c '"' } else { do $process_escapes $matched.0.content }
  }

  # Parse single-quoted value (no escape processing)
  let parse_single_quoted = {|val: string|
    let matched = ($val | parse -r "^'(?P<content>[^']*)'")
    if ($matched | is-empty) { $val | str trim -c "'" } else { $matched.0.content }
  }

  # Parse unquoted value: handle escaped hash (\#) and strip inline comments
  let parse_unquoted = {|val: string|
    $val
      | str replace -a '\#' (char nul)    # Placeholder for \#
      | split row '#'                     # Split by comment delimiter
      | first                             # Take content before first #
      | str replace -a (char nul) '#'     # Restore \# to #
      | str trim
  }

  # Parse value based on its format
  let parse_value = {|val: string|
    match $val {
      $v if ($v | str starts-with '"') => { do $parse_double_quoted $v }
      $v if ($v | str starts-with "'") => { do $parse_single_quoted $v }
      _ => { do $parse_unquoted $val }
    }
  }

  let parsed = $input | lines
    | str trim
    | compact -e
    | where {|line| not ($line | str starts-with '#') }
    | parse "{key}={value}"
    | update key {|row| $row.key | str trim | str replace -r '^export\s+' '' }
    | update value {|row| do $parse_value ($row.value | str trim) }

  if ($parsed | is-empty) { {} } else { $parsed | transpose -r -d -l }
}

# Env management tool
def --env menv [
  profile?: string,   # The name of the profile to use
  --list(-l),         # List all environment variable sets
  --silent(-s),       # Don't print the environment variables
  --encrypted(-e),    # Load environment variables from encrypted file
  --codex(-c),        # Execute codex commands: `codex -c model_provider=fox -c model_reasoning_effort=high`
  --reasoning(-r): string = 'medium',    # Reasoning effort for GPT: minimal, low, medium, high, xhigh
] {
  let currentDir = (pwd)
  let reasoningOptions = [minimal low medium high xhigh]
  let formatProfile = {|name, maxLen, envs|
    let desc = $envs | get $name | get -o description | default ''
    $'($name | fill -w $maxLen) │ (ansi grey66)($desc)(ansi rst)'
  }

  try { z share-nu }

  let envs = match $encrypted {
    true => (openssl enc -d -aes-256-cbc -a -pbkdf2 -iter 100 -in conf/sec.enc | from toml | get envs)
    _ => (open conf/sec.toml | get envs)
  }
  let envs = $envs | transpose k v | where { $in.v.deprecated? != true } | transpose -r -d -l

  if $list { $envs | columns | sort | print; cd $currentDir; return }

  if $codex and not ($reasoningOptions | any {|it| $it == $reasoning }) {
    cd $currentDir
    error make {
      msg: $'Invalid reasoning effort: ($reasoning). Allowed values: ($reasoningOptions | str join ", ").'
    }
  }

  let profile = match ($profile | is-empty) {
    true => {
      let profiles = match $codex {
        true => (
          $envs | transpose k v
            | where {|it| ($it.v.support_codex? | default false) == true }
            | get k | sort
        )
        _ => ($envs | columns | sort)
      }
      if $codex and ($profiles | is-empty) {
        print 'No environment profile with support_codex = true found.'
        cd $currentDir
        return
      }
      let maxLen = $profiles | each { str length } | math max
      $profiles
        | each {|name| do $formatProfile $name $maxLen $envs }
        | str join (char nl)
        | fzf --ansi --layout=reverse --height=50% --highlight-line
        | split row ' │ ' | first | str trim
    }
    _ => $profile
  }

  if ($profile | is-empty) { cd $currentDir; return }

  let setting = $envs | get -o $profile
  if ($setting | is-empty) { print $'Environment Profile (ansi r)($profile)(ansi rst) not found.'; cd $currentDir; return }

  if $codex and (($setting.support_codex? | default false) != true) {
    print $'Environment Profile (ansi r)($profile)(ansi rst) does not support codex.'
    cd $currentDir
    return
  }

  let baseSetting = $setting | reject -o description support_codex
  let settingToLoad = match [$codex ($baseSetting | columns | any {|k| $k == 'CODEX_AUTH_TOKEN' })] {
    [true true] => ($baseSetting | upsert ANTHROPIC_AUTH_TOKEN ($baseSetting | get CODEX_AUTH_TOKEN))
    _ => $baseSetting
  }

  if not $silent { print $settingToLoad }
  load-env $settingToLoad
  cd $currentDir
  print $'Eniroment of (ansi g)($profile)(ansi rst) loaded.'

  if $codex {
    ^codex -c $'model_provider=($profile | split row - | first)' -c $'model_reasoning_effort=($reasoning)' --dangerously-bypass-approvals-and-sandbox
  }
}

# Load environment variables from envio profile.
def --env use-env [profile: string, --silent(-s)] {
  let envs = envio list -n $profile -v
    | lines
    | parse '{key}={value}'
    | reduce -f {} { |it, acc| $acc | insert $it.key ($it.value | str trim -c '"') }

  if not $silent { print $envs }
  load-env $envs
}

# Change to the specified directory using fzf
def --env c [] {
  $env.CD_DIRS = 'acrm-ui,asrm,buyer,rad-ui,wx,bulma-ui,carbon,csp-portal,ep,imall,pp-fe,terp,service,termix-nu,b2b,material,slim,flex,setup-nu,setup-moonbit'
  let dest = $env.CD_DIRS | split row ',' | str join (char nl)
    | fzf --layout=reverse --height=50%
  z $dest
}

def "cargo search" [ query: string, --limit=10 ] {
  ^cargo search $query --limit $limit
    | lines
    | each { |line|
        if ($line | str contains "#") {
          $line | parse --regex '(?P<name>.+) = "(?P<version>.+)" +# (?P<description>.+)'
        } else {
          $line | parse --regex '(?P<name>.+) = "(?P<version>.+)"'
        }
      }
    | flatten
}

# Count Nu source codes
def nu-sloc [] {
  let stats = (
    ls **/*.nu
      | select name
      | insert lines {|it| open $it.name | str stats | get lines }
      | insert blank {|s| $s.lines - (open $s.name | lines | find --regex '\S' | length) }
      | insert comments {|s| open $s.name | lines | find --regex '^\s*#' | length }
      | sort-by lines -r
  )

  let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
  let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
  let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
  let total = ($stats | length)
  let avg = ($lines / $total | math round)

  print $'(char nl)(ansi pr) SLOC Summary for Nushell (ansi rst)(char nl)'
  print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
  print $'(char nl)Source file stat detail:'
  print $stats
}

# Check how many downloads Nushell has had
def nudown [] {
  http get https://api.github.com/repos/nushell/nushell/releases
    | get assets
    | flatten
    | select name download_count created_at
    | update created_at {|it| $it.created_at | into datetime }
    | where created_at > 2022-07-05T17:00:56Z
    # | update created_at {|it| $it | format date '%m/%d/%Y %H:%M:%S' }
}

# Download file with nu
def nu-get [
  url: string
  --directory (-d): directory # Base dir
  --output (-o): path         # File name
  --force (-f)                # Overwrite file
  --silent (-s)               # Don't print anything
] {
  if ($directory | is-not-empty) { cd $directory }
  let $file_name = $output | default { $url | url parse | get path | split row '/' | last }

  if not $force and ($file_name | path exists) { error make -u { msg: 'File already exists' } }

  let $time = timeit { http get $url | save --progress --force=$force $file_name }

  if not $silent {
    print 'Download results:'
    {
      url: $url
      file: ($file_name | path basename)
      cwd: ($file_name | path expand | path dirname)
      time: $time
      speed: $'((ls $file_name | get 0.size) / ($time | into int | $in / 10 ** 9))/s'
    } | print
  }
}

const FZF_THEME = '--color=bg+:#3c3836,bg:#32302f,spinner:#fb4934,hl:#928374,fg:#ebdbb2,header:#928374,info:#8ec07c,pointer:#fb4934,marker:#fb4934,fg+:#ebdbb2,prompt:#fb4934,hl+:#fb4934'

# -------------------------- Custom Configs ------------------------
# Nushell Config File

# For more information on defining custom themes, see
# https://www.nushell.sh/book/coloring_and_theming.html
# And here is the theme collection
# https://github.com/nushell/nu_scripts/tree/main/themes

use std/config *

$env.config.color_config = (dark-theme)

# Enable or disable the welcome banner at startup
$env.config.show_banner = false

$env.config.table = {
  mode: light                 # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
  index_mode: always          # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
  show_empty: false           # show 'empty list' and 'empty record' placeholders for command output
  padding: { left: 1, right: 1 }      # a left right padding of each column in a table
  trim: {
    methodology: wrapping             # wrapping or truncating
    truncating_suffix: "..."          # A suffix used by the 'truncating' methodology
    wrapping_try_keep_words: true     # A strategy used by the 'wrapping' methodology
  }
  abbreviated_row_count: null         # abbreviated_row_count (int or nothing): If set to `null`, all table rows will be displayed
                                      # If set to an int, all tables will be abbreviated to only show the first <n> and last <n> rows
  footer_inheritance: false           # render footer in parent table if child is big enough (extended table option)
  header_on_separator: false          # show header text on separator/border line
}

$env.config.completions = {
  quick: true                 # set this to false to prevent auto-selecting completions when only one remains
  partial: true               # set this to false to prevent partial filling of the prompt
  sort: "smart"               # "smart" (alphabetical for prefix matching, fuzzy score for fuzzy matching) or "alphabetical"
  algorithm: "prefix"         # prefix or fuzzy
  case_sensitive: false       # set to true to enable case-sensitive completions
  external: {
    enable: true              # set to false to prevent Nushell looking into $env.PATH to find more suggestions, `false` recommended for WSL users as this look up may be very slow
    max_results: 100          # setting it lower can improve completion performance at the cost of omitting some options
    completer: null           # check 'carapace_completer' above as an example
  }
  use_ls_colors: true         # set this to true to enable file/path/directory completions using LS_COLORS
}

$env.config.history = {
  isolation: false            # Only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
  max_size: 5_000_000         # Session has to be reloaded for this to take effect
  sync_on_enter: true         # Enable to share history between multiple sessions, else you have to close the session to write history to file
  file_format: "sqlite"       # "sqlite" or "plaintext"
}

$env.config.hooks = {
  pre_prompt: [{ null }]              # run before the prompt is shown
  pre_execution: [{ null }]           # run before the repl input is run
  env_change: {
    PWD: [{ |before, after|
    }],
    RELOAD_NU: [{
      condition: {|before, after|  $after | into bool }
      code: "$env.RELOAD_NU = false; source $nu.env-path;source $nu.config-path;print 'Reloaded Nu Config'"
    }]
  }
  # run before the output of a command is drawn, example: `{ if (term size).columns >= 100 { table -e } else { table } }`
  display_output: {
    if (term size).columns >= 100 { table -e } else { table }
  }
  command_not_found: { null } # return an error message when a command is not found
}

$env.config.cursor_shape = {
  emacs: line           # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (line is the default)
  vi_insert: block      # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (block is the default)
  vi_normal: underscore # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (underscore is the default)
}

$env.config.keybindings ++= [{
  name: fuzzy_history
  modifier: control
  keycode: char_r
  mode: [emacs, vi_normal, vi_insert]
  event: [
    {
      send: ExecuteHostCommand
      cmd: "do {
        $env.SHELL = $nu.current-exe
        commandline edit -r (
          history
            | get command
            | reverse
            | uniq
            | str join (char -i 0)
            | fzf --scheme=history --read0 --layout=reverse --height=40% --bind 'tab:change-preview-window(right,70%|right)' -q (commandline) --preview='print -n {} | nu --stdin -c "nu-highlight"'
            | decode utf-8
            | str trim
        )
      }"
    }
  ]
}, {
  name: reload_config
  modifier: control
  keycode: char_g
  mode: emacs
  event: {
    send: executehostcommand,
    cmd: $"source '($nu.config-path)'"
  }
}]

# REF: https://github.com/atuinsh/atuin
# atuin init nu --disable-up-arrow | save -rf ~/.local/share/atuin/init.nu
source $'($nu.home-dir)/.atuin.nu'
source $'($nu.home-dir)/.config/carapace/init.nu'

# ----------------------- ENV VARS ------------------------
$env.EDITOR = 'hx'

let poshDir = if (isWindows) {
    which oh-my-posh | get path | path dirname | path dirname | get 0
  } else { brew --prefix oh-my-posh | str trim }
let poshTheme = if (isWindows) { $'($poshDir)/themes/' } else { $'($poshDir)/share/oh-my-posh/themes/' }
# Recommend themes: zash*/space/robbyrussel/powerline/powerlevel10k_lean*/material/half-life/lambda
# Recommend double lines: amro/pure/spaceship
oh-my-posh init nu --config $'($poshTheme)/zash.omp.json'
