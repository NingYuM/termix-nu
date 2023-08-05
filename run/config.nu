# Nushell Config File
# Update config from: ba0f069c3
# version = 0.83.2

# source ~/.config/nushell/config.nu
# Ref:
#   1. https://ohmyposh.dev/docs/themes
#   2. https://github.com/nushell/nushell/issues/4300 Config Settings
#   3. https://github.com/nushell/nushell/blob/main/docs/How_To_Coloring_and_Theming.md

# use ~/github/terminus/termix-nu/run/zoxide-eq.nu [z, zi]
source ~/.zoxide.nu

# ---------------------- Aliases -------------------------
alias ll = exa -l
alias la = exa -la
alias .. = cd ..
alias ... = do { cd ..; cd .. }
alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .
alias nuc = print (help commands | where command_type != custom and command_type != alias | reject signatures search_terms)
alias nucc = print (help commands | where command_type != custom and command_type != alias | length)
alias tokeid = print (tokei | lines | skip 1 | str join "\n" | detect columns | where {|it| $it.Language !~ "=" and $it.Language !~ "-" and (not ($it.Files | is-empty)) } | into int Files Lines Code Comments Blanks)

# ----------------------- ENV VARS ------------------------
$env.EDITOR = 'hx'
# Use nushell functions to define your right and left prompt
$env.PROMPT_COMMAND_RIGHT = { '' }

let poshDir = (brew --prefix oh-my-posh | str trim)
let poshTheme = $'($poshDir)/share/oh-my-posh/themes/'
# Recommend themes: zash*/space/robbyrussel/powerline/powerlevel10k_lean*/material/half-life/lambda
# Recommend double lines: amro/pure/spaceship
$env.PROMPT_COMMAND = { oh-my-posh prompt print primary --config $'($poshTheme)/zash.omp.json' }
$env.PROMPT_INDICATOR = $"(ansi y)$> (ansi reset)"

# $env.PATH = (
#   $env.PATH
#     | prepend `/Applications/Sublime Text.app/Contents/SharedSupport/bin/`
#     | prepend `/Applications/Sublime Merge.app/Contents/SharedSupport/bin/`
#     | uniq
# )

# -------------------- Custom Commands -------------------------

def cls [] { ansi cls }
def 'env exists?' [] { $in in (env).name }  # ' Just hack for syntax highlight
def sum [] { reduce {|acc, item| $acc + $item } }
def ver [] { (version | transpose key value | to md --pretty) }

def nun [] {
  http get https://api.github.com/repos/nushell/nightly/releases | sort-by -r created_at | select name tag_name id created_at
}

# 在本地构建所有 Nushell 二进制文件
def install-all-nu [] {
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
      print $'(char nl)Installing nushell'
      print '----------------------------'

      cd $nu_root
      cargo install --force --path . --features=dataframe,extra
  }

  install-nushell

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

def nu-backup-main [] { cp -r ~/.cargo/bin/nu* ~/Applications/nu-main/ }
def nu-restore-main [] { cp -r ~/Applications/nu-main/* ~/.cargo/bin/; print $'Please restart Nu session...' }
def nu-use-latest [] { cp -r ~/Applications/nu-latest/* ~/.cargo/bin/; print $'Please restart Nu session...' }
def nu-fetch-latest [] {
  cd ~/Applications/nu-latest/
  curl -s https://api.github.com/repos/nushell/nushell/releases/latest | grep browser_download_url | cut -d '"' -f 4 | grep x86_64-apple-darwin  | aria2c -i -
  mkdir nu-latest; tar xvf nu-*.tar.gz --directory=nu-latest
  cp -r nu-latest/**/* .; rm -rf nu-*
  $'(char nl)Update to Nu: (ansi g)(./nu --version)(ansi reset)'
}

def cargo-clippy [] {
  cargo clippy --all --all-features -- -D warnings -D clippy::unwrap_used -A clippy::needless_collect
}

# example usage: `$nu.config-path | goto`
def-env goto [] {
  let input = $in
  let path = if ($input | path type) == file { ($input | path dirname) } else { $input }
  cd $path
}

# Bump Nushell to new version
def bump-ver [
  --minor(-m): bool   # Bump minor version
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
def-env load-direnv [] {
  load-env (
    open --raw .envrc
      | lines
      | where $it =~ 'export'
      | parse 'export {key}={value}'
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

def 'nu-sloc' [] {
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

# Check how many downloads nushell has had
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
    bool: { if $in { 'light_cyan' } else { 'light_gray' } }
    int: white
    filesize: {|e|
      if $e == 0b {
        'white'
      } else if $e < 1mb {
        'cyan'
      } else { 'blue' }
    }
    duration: white
    date: { (date now) - $in |
      if $in < 1hr {
        'purple'
      } else if $in < 6hr {
        'red'
      } else if $in < 1day {
        'yellow'
      } else if $in < 3day {
        'green'
      } else if $in < 1wk {
        'light_green'
      } else if $in < 6wk {
        'cyan'
      } else if $in < 52wk {
        'blue'
      } else { 'dark_gray' }
    }
    range: white
    float: white
    string: white
    nothing: white
    binary: white
    cellpath: white
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
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
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
    bool: { if $in { 'dark_cyan' } else { 'dark_gray' } }
    int: dark_gray
    filesize: {|e|
      if $e == 0b {
        'dark_gray'
      } else if $e < 1mb {
        'cyan_bold'
      } else { 'blue_bold' }
    }
    duration: dark_gray
    date: { (date now) - $in |
      if $in < 1hr {
        'purple'
      } else if $in < 6hr {
        'red'
      } else if $in < 1day {
        'yellow'
      } else if $in < 3day {
        'green'
      } else if $in < 1wk {
        'light_green'
      } else if $in < 6wk {
        'cyan'
      } else if $in < 52wk {
        'blue'
      } else { 'dark_gray' }
    }
    range: dark_gray
    float: dark_gray
    string: dark_gray
    nothing: dark_gray
    binary: dark_gray
    cellpath: dark_gray
    row_index: green_bold
    record: white
    list: white
    block: white
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
    shape_filepath: cyan
    shape_flag: blue_bold
    shape_float: purple_bold
    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: white bg: red attr: b}
    shape_globpattern: cyan_bold
    shape_int: purple_bold
    shape_internalcall: cyan_bold
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
  carapace $spans.0 nushell $spans | from json
}

# The default config record. This is where much of your global configuration is setup.
$env.config = {
  # true or false to enable or disable the welcome banner at startup
  show_banner: true
  ls: {
    use_ls_colors: true         # use the LS_COLORS environment variable to colorize output
    clickable_links: true       # enable or disable clickable links. Your terminal has to support links.
  }

  rm: {
    always_trash: false         # always act as if -t was given. Can be overridden with -p
  }

  cd: {
    abbreviations: true         # allows `cd s/o/f` to expand to `cd some/other/folder`
  }

  table: {
    mode: light                 # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
    index_mode: always          # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
    show_empty: false           # show 'empty list' and 'empty record' placeholders for command output
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

  datetime_format: {
    normal: '%a, %d %b %Y %H:%M:%S %z'  # shows up in displays of variables or other datetime's outside of tables
    # table: '%m/%d/%y %I:%M:%S%p'      # generally shows up in tabular outputs such as ls. commenting this out will change it to the default human readable datetime format
  }

  # A 'explore' utility config
  explore: {
    try: {
      border_color: {fg: "white"}
    },
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
      selected_cell: {},
      selected_row: {},
      selected_column: {},
      cursor: true,
      line_shift: true,
      line_index: true,
      line_head_top: true,
      line_head_bottom: true,
    },
    config: {
      border_color: {fg: "white"}
      cursor_color: {fg: "black", bg: "light_yellow"}
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
      enable: true              # set to false to prevent nushell looking into $env.PATH to find more suggestions, `false` recommended for WSL users as this look up may be very slow
      max_results: 100          # setting it lower can improve completion performance at the cost of omitting some options
      completer: $carapace_completer           # check 'carapace_completer' above as an example
    }
  }

  filesize: {
    metric: true                # true => KB, MB, GB (ISO standard), false => KiB, MiB, GiB (Windows standard)
    format: "auto"              # b, kb, kib, mb, mib, gb, gib, tb, tib, pb, pib, eb, eib, auto
  }

  cursor_shape: {
    emacs: line                 # block, underscore, line, blink_block, blink_underscore, blink_line (line is the default)
    vi_insert: block            # block, underscore, line , blink_block, blink_underscore, blink_line (block is the default)
    vi_normal: underscore       # block, underscore, line, blink_block, blink_underscore, blink_line (underscore is the default)
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

  hooks: {
    pre_prompt: [{ null }]              # run before the prompt is shown
    pre_execution: [{ null }]           # run before the repl input is run
    env_change: {
      PWD: [{|before, after| null }]    # run if the PWD environment is different since the last repl input
    }
    # run before the output of a command is drawn, example: `{ if (term size).columns >= 100 { table -e } else { table } }`
    display_output: {
      if (term size).columns >= 100 { table -e } else { table }
    }
    command_not_found: { null } # return an error message when a command is not found
  }

  menus: [
    # Configuration for default nushell menus
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
        selected_text: green_reverse
        description_text: yellow
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
    # Example of extra menus created using a nushell source
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
  ]
}

$env.PATH = ($env.PATH | each {|r| $r | split row (char esep)} | flatten | uniq | str join (char esep))

# REF: https://github.com/atuinsh/atuin
source ~/.local/share/atuin/init.nu
