# Nushell Config File
# Update config from: c2992d5d8
# version = 0.90.1

# source ~/.config/nushell/config.nu
# Ref:
#   1. https://ohmyposh.dev/docs/themes
#   2. https://github.com/nushell/nushell/issues/4300 Config Settings
#   3. https://github.com/nushell/nushell/blob/main/docs/How_To_Coloring_and_Theming.md

use std [repeat]

# use ~/github/terminus/termix-nu/run/zoxide-eq.nu [z, zi]
source ~/.zoxide.nu

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

# ----------------------- ENV VARS ------------------------
$env.EDITOR = 'hx'
# Disable the date & time displaying on the right of prompt
$env.PROMPT_COMMAND_RIGHT = { '' }

let poshDir = (brew --prefix oh-my-posh | str trim)
let poshTheme = $'($poshDir)/share/oh-my-posh/themes/'
# Recommend themes: zash*/space/robbyrussel/powerline/powerlevel10k_lean*/material/half-life/lambda
# Recommend double lines: amro/pure/spaceship
$env.PROMPT_COMMAND = { oh-my-posh prompt print primary --config $'($poshTheme)/zash.omp.json' }
$env.PROMPT_INDICATOR = $"(ansi y)$> (ansi reset)"

$env.HOMEBREW_BOTTLE_DOMAIN = https://mirrors.ustc.edu.cn/homebrew-bottles/bottles

$env.PATH = (
  $env.PATH
    | append `/Applications/Ghostty.app/Contents/MacOS/`
    # | prepend `/Applications/Sublime Merge.app/Contents/SharedSupport/bin/`
    | uniq
)

# -------------------- Custom Commands -------------------------

# Clear screen
def cls [] { ansi cls }
def 'env exists?' [] { $in in (env).name }  # ' Just hack for syntax highlight
# Sum input numbers
def sum [] { reduce {|acc, item| $acc + $item } }
# Display Nu version info in markdown format
def ver [] { (version | transpose key value | to md --pretty) }

# Print a horizontal line
export def hr-line [
  width?: int = 90,
  --color(-c): string = 'g',
  --blank-line(-b),
  --with-arrow(-a),
] {
  print $'(ansi $color)('─' | repeat $width | str join)(if $with_arrow {'>'})(ansi reset)'
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
    print $'Pull all from (ansi p)($env.PWD)(ansi reset):'
    hr-line; t pull-all; print (char nl)
  }
}

# Clean nightly Tags:
# `git tag -l | lines | filter { $in =~ nightly } | each { git tag -d $in }`
# Show Nu nightly builds information
def nun [] {
  http get https://api.github.com/repos/nushell/nightly/releases
    | sort-by -r created_at
    | select name tag_name id created_at
}

# Pipe stdout + stderr
# You can do `run cargo run --quiet` and everything will pass through correctly.
# For that you're giving up the ability to control the flags to run-external
def --wrapped run [cmd ...args] { run-external --redirect-combine $cmd $args }

# 在本地构建并安装所有 Nushell 二进制文件
def install-all-nu [
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
      cargo install --force --locked --path . --features=dataframe,extra
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
      nu_plugin_example,
      nu_plugin_custom_values,
      nu_plugin_formats,
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
    | grep x86_64-darwin-full
    | aria2c -i -
  mkdir nu-latest; tar xvf nu-*.tar.gz --directory=nu-latest
  cp -r nu-latest/**/* .; rm -rf nu-*
  $'(char nl)Update to Nu: (ansi g)(./nu --version)(ansi reset)'
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
    | filter { $in =~ 'x86_64-darwin-full' }
    | get 0
    | aria2c -i -
  mkdir nu-nightly; tar xvf nu-*.tar.gz --directory=nu-nightly
  cp -r nu-nightly/**/* .; rm -rf nu-*
  $'(char nl)Update to Nu: (ansi g)(./nu --version)(ansi reset)'
}

def cargo-clippy [] {
  cargo clippy --all --all-features -- -D warnings -D clippy::unwrap_used -A clippy::needless_collect
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
      echo $"Unknown extension: ($p)"
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
      echo $"Unknown extension: ($p)"
    }

  }
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

# Load environment variables from the .env file.
def --env load-dot-env [
  path: string = '.env'
] {
  load-env (
    open --raw $path
      | str replace -a '"' ''
      | str replace -a "'" ''
      | lines
      | parse '{key}={value}'
      | reduce -f {} { |it, acc| $acc | insert $it.key ($it.value | str trim -c '"') }  # "
  )
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
      | insert lines {|it| open $it.name | size | get lines }
      | insert blank {|s| $s.lines - (open $s.name | lines | find --regex '\S' | length) }
      | insert comments {|s| open $s.name | lines | find --regex '^\s*#' | length }
      | sort-by lines -r
  )

  let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
  let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
  let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
  let total = ($stats | length)
  let avg = ($lines / $total | math round)

  $'(char nl)(ansi pr) SLOC Summary for Nushell (ansi reset)(char nl)'
  print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
  $'(char nl)Source file stat detail:'
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

# -------------------------- Autocompletion ------------------------
# Nushell Config File

# For more information on defining custom themes, see
# https://www.nushell.sh/book/coloring_and_theming.html
# And here is the theme collection
# https://github.com/nushell/nu_scripts/tree/main/themes
let dark_theme = {
    # color for nushell primitives
    separator: white
    leading_trailing_space_bg: { attr: n } # no fg, no bg, attr none effectively turns this off
    header: green_bold
    empty: blue
    # Closures can be used to choose colors for specific values.
    # The value (in this case, a bool) is piped into the closure.
    # eg) {|| if $in { 'light_cyan' } else { 'light_gray' } }
    bool: light_cyan
    int: white
    filesize: cyan
    duration: white
    date: purple
    range: white
    float: white
    string: white
    nothing: white
    binary: white
    cell-path: white
    row_index: green_bold
    record: white
    list: white
    block: white
    hints: dark_gray
    search_result: {bg: red fg: white}
    shape_and: purple_bold
    shape_binary: purple_bold
    shape_block: blue_bold
    shape_bool: light_cyan
    shape_closure: green_bold
    shape_custom: green
    shape_datetime: cyan_bold
    shape_directory: cyan
    shape_external: cyan
    shape_externalarg: green_bold
    shape_external_resolved: light_yellow_bold
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
    shape_keyword: cyan_bold
    shape_list: cyan_bold
    shape_literal: blue
    shape_match_pattern: green
    shape_matching_brackets: { attr: u }
    shape_nothing: light_cyan
    shape_operator: yellow
    shape_or: purple_bold
    shape_pipe: purple_bold
    shape_range: yellow_bold
    shape_record: cyan_bold
    shape_redirection: purple_bold
    shape_signature: green_bold
    shape_string: green
    shape_string_interpolation: cyan_bold
    shape_table: blue_bold
    shape_variable: purple
    shape_vardecl: purple
}

let light_theme = {
    # color for nushell primitives
    separator: dark_gray
    leading_trailing_space_bg: { attr: n } # no fg, no bg, attr none effectively turns this off
    header: green_bold
    empty: blue
    # Closures can be used to choose colors for specific values.
    # The value (in this case, a bool) is piped into the closure.
    # eg) {|| if $in { 'dark_cyan' } else { 'dark_gray' } }
    bool: dark_cyan
    int: dark_gray
    filesize: cyan_bold
    duration: dark_gray
    date: purple
    range: dark_gray
    float: dark_gray
    string: dark_gray
    nothing: dark_gray
    binary: dark_gray
    cell-path: dark_gray
    row_index: green_bold
    record: dark_gray
    list: dark_gray
    block: dark_gray
    hints: dark_gray
    search_result: {fg: white bg: red}
    shape_and: purple_bold
    shape_binary: purple_bold
    shape_block: blue_bold
    shape_bool: light_cyan
    shape_closure: green_bold
    shape_custom: green
    shape_datetime: cyan_bold
    shape_directory: cyan
    shape_external: cyan
    shape_externalarg: green_bold
    shape_external_resolved: light_purple_bold
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
    shape_keyword: cyan_bold
    shape_list: cyan_bold
    shape_literal: blue
    shape_match_pattern: green
    shape_matching_brackets: { attr: u }
    shape_nothing: light_cyan
    shape_operator: yellow
    shape_or: purple_bold
    shape_pipe: purple_bold
    shape_range: yellow_bold
    shape_record: cyan_bold
    shape_redirection: purple_bold
    shape_signature: green_bold
    shape_string: green
    shape_string_interpolation: cyan_bold
    shape_table: blue_bold
    shape_variable: purple
    shape_vardecl: purple
}

let carapace_completer = {|spans|
  carapace $spans.0 nushell ...$spans | from json
}

# The default config record. This is where much of your global configuration is setup.
$env.config = {
  # true or false to enable or disable the welcome banner at startup
  show_banner: false
  ls: {
    use_ls_colors: true         # use the LS_COLORS environment variable to colorize output
    clickable_links: true       # enable or disable clickable links. Your terminal has to support links.
  }

  rm: {
    always_trash: false         # always act as if -t was given. Can be overridden with -p
  }

  table: {
    mode: light                 # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
    index_mode: always          # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
    show_empty: false           # show 'empty list' and 'empty record' placeholders for command output
    padding: { left: 1, right: 1 }      # a left right padding of each column in a table
    trim: {
      methodology: wrapping             # wrapping or truncating
      truncating_suffix: "..."          # A suffix used by the 'truncating' methodology
      wrapping_try_keep_words: true     # A strategy used by the 'wrapping' methodology
    }
    header_on_separator: false          # show header text on separator/border line
  }
  # datetime_format determines what a datetime rendered in the shell would look like.
  # Behavior without this configuration point will be to "humanize" the datetime display,
  # showing something like "a day ago."

  error_style: "fancy"                  # "fancy" or "plain" for screen reader-friendly error messages

  datetime_format: {
    normal: '%a, %d %b %Y %H:%M:%S %z'  # shows up in displays of variables or other datetime's outside of tables
    # table: '%m/%d/%y %I:%M:%S%p'      # generally shows up in tabular outputs such as ls. commenting this out will change it to the default human readable datetime format
  }

  # A 'explore' utility config
  explore: {
    status_bar_background: {fg: "#1D1F21", bg: "#C4C9C6"},
    command_bar_text: {fg: "#C4C9C6"},
    highlight: {fg: "black", bg: "yellow"},
    status: {
      warn: {},
      info: {},
      error: {fg: "white", bg: "red"},
    },
    table: {
      split_line: {fg: "#404040"},
      selected_cell: {bg: light_blue},
      selected_row: {},
      selected_column: {},
    },
  }

  history: {
    max_size: 100_000           # Session has to be reloaded for this to take effect
    sync_on_enter: true         # Enable to share history between multiple sessions, else you have to close the session to write history to file
    file_format: "sqlite"       # "sqlite" or "plaintext"
    isolation: false            # Only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
  }

  completions: {
    quick: true                 # set this to false to prevent auto-selecting completions when only one remains
    partial: true               # set this to false to prevent partial filling of the prompt
    algorithm: "prefix"         # prefix or fuzzy
    case_sensitive: false       # set to true to enable case-sensitive completions
    external: {
      enable: true              # set to false to prevent Nushell looking into $env.PATH to find more suggestions, `false` recommended for WSL users as this look up may be very slow
      max_results: 100          # setting it lower can improve completion performance at the cost of omitting some options
      completer: $carapace_completer           # check 'carapace_completer' above as an example
    }
  }

  filesize: {
    metric: true                # true => KB, MB, GB (ISO standard), false => KiB, MiB, GiB (Windows standard)
    format: "auto"              # b, kb, kib, mb, mib, gb, gib, tb, tib, pb, pib, eb, eib, auto
  }

  cursor_shape: {
    emacs: line           # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (line is the default)
    vi_insert: block      # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (block is the default)
    vi_normal: underscore # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (underscore is the default)
  }

  color_config: $dark_theme     # if you want a light theme, replace `$dark_theme` to `$light_theme`
  use_grid_icons: true
  footer_mode: "25"             # always, never, number_of_rows, auto
  float_precision: 2            # the precision for displaying floats in tables
  # buffer_editor: "emacs"      # command that will be used to edit the current line buffer with ctrl+o, if unset fallback to $env.EDITOR and $env.VISUAL
  use_ansi_coloring: true
  bracketed_paste: true         # enable bracketed paste, currently useless on windows
  edit_mode: emacs              # emacs, vi
  shell_integration: true       # enables terminal shell integration. Off by default, as some terminals have issues with this.
  render_right_prompt_on_last_line: false   # true or false to enable or disable right prompt to be rendered on last line of the prompt.
  use_kitty_protocol: false           # enables keyboard enhancement protocol implemented by kitty console, only if your terminal support this.
  highlight_resolved_externals: false # true enables highlighting of external commands in the repl resolved by which.

  plugins: {}             # Per-plugin configuration. See https://www.nushell.sh/contributor-book/plugins.html#configuration.
  hooks: {
    pre_prompt: [{ null }]              # run before the prompt is shown
    pre_execution: [{ null }]           # run before the repl input is run
    env_change: {
      PWD: [{ |before, after|
        if ('FNM_DIR' in $env) and ([.nvmrc .node-version] | path exists | any { |it| $it }) {
          fnm use
        }
      }],
      RELOAD_NU: [{
        condition: {|before, after|  $after }
        code: "$env.RELOAD_NU = false; source $nu.env-path;source $nu.config-path;print 'Reloaded Nu Config'"
      }]
    }
    # run before the output of a command is drawn, example: `{ if (term size).columns >= 100 { table -e } else { table } }`
    display_output: {
      if (term size).columns >= 100 { table -e } else { table }
    }
    command_not_found: { null } # return an error message when a command is not found
  }

  menus: [
    # Configuration for default Nushell menus
    # Note the lack of source parameter
    {
      name: completion_menu
      only_buffer_difference: false
      marker: "| "
      type: {
        layout: columnar
        columns: 4
        col_width: 20           # Optional value. If missing all the screen width is used to calculate column width
        col_padding: 2
      }
      style: {
        text: green
        selected_text: {attr: r}
        description_text: yellow
        match_text: {attr: u}
        selected_match_text: {attr: ur}
      }
    }
    {
      name: ide_completion_menu
      only_buffer_difference: false
      marker: "| "
      type: {
        layout: ide
        min_completion_width: 0,
        max_completion_width: 50,
        # max_completion_height: 10, # will be limited by the available lines in the terminal
        padding: 0,
        border: true,
        cursor_offset: 0,
        description_mode: "prefer_right"
        min_description_width: 0
        max_description_width: 50
        max_description_height: 10
        description_offset: 1
        # If true, the cursor pos will be corrected, so the suggestions match up with the typed text
        #
        # C:\> str
        #      str join
        #      str trim
        #      str split
        correct_cursor_pos: false
      }
      style: {
        text: green
        selected_text: {attr: r}
        description_text: yellow
        match_text: {attr: u}
        selected_match_text: {attr: ur}
      }
    }
    {
      name: history_menu
      only_buffer_difference: true
      marker: "? "
      type: {
        layout: list
        page_size: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
    }
    {
      name: help_menu
      only_buffer_difference: true
      marker: "? "
      type: {
        layout: description
        columns: 4
        col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
        col_padding: 2
        selection_rows: 4
        description_rows: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
    }
    # Example of extra menus created using a Nushell source
    # Use the source field to create a list of records that populates
    # the menu
    {
      name: commands_menu
      only_buffer_difference: false
      marker: "# "
      type: {
        layout: columnar
        columns: 4
        col_width: 20
        col_padding: 2
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
      source: { |buffer, position|
        scope commands
          | where command =~ $buffer
          | each { |it| {value: $it.command description: $it.usage} }
      }
    }
    {
      name: vars_menu
      only_buffer_difference: true
      marker: "# "
      type: {
        layout: list
        page_size: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
      source: { |buffer, position|
        scope variables
          | where name =~ $buffer
          | sort-by name
          | each { |it| {value: $it.name description: $it.type} }
      }
    }
    {
      name: commands_with_description
      only_buffer_difference: true
      marker: "# "
      type: {
        layout: description
        columns: 4
        col_width: 20
        col_padding: 2
        selection_rows: 4
        description_rows: 10
      }
      style: {
        text: green
        selected_text: green_reverse
        description_text: yellow
      }
      source: { |buffer, position|
        scope commands
          | where command =~ $buffer
          | each { |it| {value: $it.command description: $it.usage} }
      }
    }
  ]
  keybindings: [
    {
      name: completion_menu
      modifier: none
      keycode: tab
      mode: emacs # Options: emacs vi_normal vi_insert
      event: {
        until: [
          { send: menu name: completion_menu }
          { send: menunext }
          { edit: complete }
        ]
      }
    }
    {
      name: completion_previous
      modifier: shift
      keycode: backtab
      mode: [emacs, vi_normal, vi_insert] # Note: You can add the same keybinding to all modes by using a list
      event: { send: menuprevious }
    }
    {
      name: ide_completion_menu
      modifier: control
      keycode: char_n
      mode: [emacs vi_normal vi_insert]
      event: {
        until: [
          { send: menu name: ide_completion_menu }
          { send: menunext }
          { edit: complete }
        ]
      }
    }
    {
      name: fuzzy_history
      modifier: control
      keycode: char_r
      mode: [emacs, vi_normal, vi_insert]
      event: [
        {
          send: ExecuteHostCommand
          cmd: "commandline (
            history
              | each { |it| $it.command }
              | uniq
              | reverse
              | str join (char -i 0)
              | fzf --read0 --layout=reverse --height=40% -q (commandline)
              | decode utf-8
              | str trim
          )"
        }
      ]
    }
    {
      name: next_page
      modifier: control
      keycode: char_x
      mode: emacs
      event: { send: menupagenext }
    }
    {
      name: undo_or_previous_page
      modifier: control
      keycode: char_z
      mode: emacs
      event: {
        until: [
          { send: menupageprevious }
          { edit: undo }
        ]
      }
    }
    {
      name: yank
      modifier: control
      keycode: char_y
      mode: emacs
      event: {
        until: [
          {edit: pastecutbufferafter}
        ]
      }
    }
    {
      name: unix-line-discard
      modifier: control
      keycode: char_u
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {edit: cutfromlinestart}
        ]
      }
    }
    {
      name: kill-line
      modifier: control
      keycode: char_k
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {edit: cuttolineend}
        ]
      }
    }
    {
      name: cargo_test
      modifier: alt
      keycode: char_t
      mode: emacs
      event: [
        { edit: clear }
        { edit: insertString value: "cargo test --all --all-features" }
        { send: enter }
      ]
    },
    {
      name: reload_config
      modifier: control
      keycode: char_g
      mode: emacs
      event: {
        send: executehostcommand,
        cmd: $"source '($nu.config-path)'"
      }
      # event: [
      #   { edit: clear }
      #   { edit: insertString value: $"source '($nu.config-path)'" }
      #   { send: Enter }
      # ]
    }
    # Keybindings used to trigger the user defined menus
    {
      name: commands_menu
      modifier: control
      keycode: char_t
      mode: [emacs, vi_normal, vi_insert]
      event: { send: menu name: commands_menu }
    }
    {
      name: vars_menu
      modifier: alt
      keycode: char_o
      mode: [emacs, vi_normal, vi_insert]
      event: { send: menu name: vars_menu }
    }
    {
      name: commands_with_description
      modifier: control
      keycode: char_s
      mode: [emacs, vi_normal, vi_insert]
      event: { send: menu name: commands_with_description }
    }
    {
      name: move_up
      modifier: none
      keycode: up
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: menuup}
          {send: up}
        ]
      }
    }
    {
      name: move_down
      modifier: none
      keycode: down
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: menudown}
          {send: down}
        ]
      }
    }
    {
      name: move_left
      modifier: none
      keycode: left
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: menuleft}
          {send: left}
        ]
      }
    }
    {
      name: move_right_or_take_history_hint
      modifier: none
      keycode: right
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: historyhintcomplete}
          {send: menuright}
          {send: right}
        ]
      }
    }
    {
      name: move_one_word_left
      modifier: control
      keycode: left
      mode: [emacs, vi_normal, vi_insert]
      event: {edit: movewordleft}
    }
    {
      name: move_one_word_right_or_take_history_hint
      modifier: control
      keycode: right
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: historyhintwordcomplete}
          {edit: movewordright}
        ]
      }
    }
    {
      name: move_to_line_start
      modifier: none
      keycode: home
      mode: [emacs, vi_normal, vi_insert]
      event: {edit: movetolinestart}
    }
    {
      name: move_to_line_start
      modifier: control
      keycode: char_a
      mode: [emacs, vi_normal, vi_insert]
      event: {edit: movetolinestart}
    }
    {
      name: move_to_line_end_or_take_history_hint
      modifier: none
      keycode: end
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: historyhintcomplete}
          {edit: movetolineend}
        ]
      }
    }
    {
      name: move_to_line_end_or_take_history_hint
      modifier: control
      keycode: char_e
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: historyhintcomplete}
          {edit: movetolineend}
        ]
      }
    }
    {
      name: move_to_line_start
      modifier: control
      keycode: home
      mode: [emacs, vi_normal, vi_insert]
      event: {edit: movetolinestart}
    }
    {
      name: move_to_line_end
      modifier: control
      keycode: end
      mode: [emacs, vi_normal, vi_insert]
      event: {edit: movetolineend}
    }
    {
      name: move_up
      modifier: control
      keycode: char_p
      mode: [emacs, vi_normal, vi_insert]
      event: {
        until: [
          {send: menuup}
          {send: up}
        ]
      }
    }
    {
      name: move_down
      modifier: control
      keycode: char_t
      mode: [emacs, vi_normal, vi_insert]
      event: {
          until: [
              {send: menudown}
              {send: down}
          ]
      }
    }
    {
      name: delete_one_character_backward
      modifier: none
      keycode: backspace
      mode: [emacs, vi_insert]
      event: {edit: backspace}
    }
    {
      name: delete_one_word_backward
      modifier: control
      keycode: backspace
      mode: [emacs, vi_insert]
      event: {edit: backspaceword}
    }
    {
      name: delete_one_character_forward
      modifier: none
      keycode: delete
      mode: [emacs, vi_insert]
      event: {edit: delete}
    }
    {
      name: delete_one_character_forward
      modifier: control
      keycode: delete
      mode: [emacs, vi_insert]
      event: {edit: delete}
    }
    {
      name: delete_one_character_forward
      modifier: control
      keycode: char_h
      mode: [emacs, vi_insert]
      event: {edit: backspace}
    }
    {
      name: delete_one_word_backward
      modifier: control
      keycode: char_w
      mode: [emacs, vi_insert]
      event: {edit: backspaceword}
    }
    {
      name: move_left
      modifier: none
      keycode: backspace
      mode: vi_normal
      event: {edit: moveleft}
    }
    {
      name: newline_or_run_command
      modifier: none
      keycode: enter
      mode: emacs
      event: {send: enter}
    }
    {
      name: move_left
      modifier: control
      keycode: char_b
      mode: emacs
      event: {
        until: [
          {send: menuleft}
          {send: left}
        ]
      }
    }
    {
      name: move_right_or_take_history_hint
      modifier: control
      keycode: char_f
      mode: emacs
      event: {
        until: [
          {send: historyhintcomplete}
          {send: menuright}
          {send: right}
        ]
      }
    }
    {
      name: redo_change
      modifier: control
      keycode: char_g
      mode: emacs
      event: {edit: redo}
    }
    {
      name: undo_change
      modifier: control
      keycode: char_z
      mode: emacs
      event: {edit: undo}
    }
    {
      name: paste_before
      modifier: control
      keycode: char_y
      mode: emacs
      event: {edit: pastecutbufferbefore}
    }
    {
      name: cut_word_left
      modifier: control
      keycode: char_w
      mode: emacs
      event: {edit: cutwordleft}
    }
    {
      name: cut_line_to_end
      modifier: control
      keycode: char_k
      mode: emacs
      event: {edit: cuttoend}
    }
    {
      name: cut_line_from_start
      modifier: control
      keycode: char_u
      mode: emacs
      event: {edit: cutfromstart}
    }
    {
      name: swap_graphemes
      modifier: control
      keycode: char_t
      mode: emacs
      event: {edit: swapgraphemes}
    }
    {
      name: move_one_word_left
      modifier: alt
      keycode: left
      mode: emacs
      event: {edit: movewordleft}
    }
    {
      name: move_one_word_right_or_take_history_hint
      modifier: alt
      keycode: right
      mode: emacs
      event: {
        until: [
          {send: historyhintwordcomplete}
          {edit: movewordright}
        ]
      }
    }
    {
      name: move_one_word_left
      modifier: alt
      keycode: char_b
      mode: emacs
      event: {edit: movewordleft}
    }
    {
      name: move_one_word_right_or_take_history_hint
      modifier: alt
      keycode: char_f
      mode: emacs
      event: {
        until: [
          {send: historyhintwordcomplete}
          {edit: movewordright}
        ]
      }
    }
    {
      name: delete_one_word_forward
      modifier: alt
      keycode: delete
      mode: emacs
      event: {edit: deleteword}
    }
    {
      name: delete_one_word_backward
      modifier: alt
      keycode: backspace
      mode: emacs
      event: {edit: backspaceword}
    }
    {
      name: delete_one_word_backward
      modifier: alt
      keycode: char_m
      mode: emacs
      event: {edit: backspaceword}
    }
    {
      name: cut_word_to_right
      modifier: alt
      keycode: char_d
      mode: emacs
      event: {edit: cutwordright}
    }
    {
      name: upper_case_word
      modifier: alt
      keycode: char_u
      mode: emacs
      event: {edit: uppercaseword}
    }
    {
      name: lower_case_word
      modifier: alt
      keycode: char_l
      mode: emacs
      event: {edit: lowercaseword}
    }
    {
      name: capitalize_char
      modifier: alt
      keycode: char_c
      mode: emacs
      event: {edit: capitalizechar}
    }
    {
      name: copy_selection
      modifier: control_shift
      keycode: char_c
      mode: emacs
      event: { edit: copyselection }
    }
    {
      name: cut_selection
      modifier: control_shift
      keycode: char_x
      mode: emacs
      event: { edit: cutselection }
    }
    {
      name: select_all
      modifier: control_shift
      keycode: char_a
      mode: emacs
      event: { edit: selectall }
    }
    {
      name: paste
      modifier: control_shift
      keycode: char_v
      mode: emacs
      event: { edit: pastecutbufferbefore }
    }
  ]
}

$env.PATH = ($env.PATH | each {|r| $r | split row (char esep)} | flatten | uniq | str join (char esep))

# REF: https://github.com/atuinsh/atuin
# atuin init nu --disable-up-arrow | save -rf ~/.local/share/atuin/init.nu
source ~/.local/share/atuin/init.nu
