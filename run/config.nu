
# source ~/.config/nushell/config.nu
# Ref:
#   1. https://ohmyposh.dev/docs/themes
#   2. https://github.com/nushell/nushell/issues/4300 Config Settings
#   3. https://github.com/nushell/nushell/blob/main/docs/How_To_Coloring_and_Theming.md

source ~/github/terminus/termix-nu/run/zoxide-eq.nu

# ---------------------- Aliases -------------------------
alias ll = exa -l
alias la = exa -la
alias .. = cd ..
alias ... = 'cd .. ; cd ..'
alias t = just --justfile ~/.justfile --dotenv-path ~/.env --working-directory .
alias tokeid = (tokei | lines | skip 1 | str collect "\n" | detect columns | where Language !~ "=" && Language !~ "|" && Language !~ "-" && Language !~ "(" | into int Files Lines Code Comments Blanks)

# ----------------------- ENV VARS ------------------------
# Use nushell functions to define your right and left prompt
let-env PROMPT_COMMAND_RIGHT = { '' }
# The prompt indicators are environmental variables that represent
# the state of the prompt
let-env PROMPT_INDICATOR_VI_INSERT = ": "
let-env PROMPT_INDICATOR_VI_NORMAL = "〉"
let-env PROMPT_MULTILINE_INDICATOR = "::: "

let posh-dir = (brew --prefix oh-my-posh | str trim)
let posh-theme = $'($posh-dir)/share/oh-my-posh/themes/'
# Recomend themes: zash*/space/robbyrussel/powerline/powerlevel10k_lean*/material/half-life/lambda
# Recomend double lines: amro/pure/spaceship
let-env PROMPT_COMMAND = { oh-my-posh --config $'($posh-theme)/zash.omp.json' }
let-env PROMPT_INDICATOR = $"(ansi y)$> (ansi reset)"

# Specifies how environment variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running extrnal commands (to_string)
let-env ENV_CONVERSIONS = {
  "PATH": {
    from_string: { |s| $s | split row (char esep) }
    to_string: { |v| $v | str collect (char esep) }
  }
  "Path": {
    from_string: { |s| $s | split row (char esep) }
    to_string: { |v| $v | str collect (char esep) }
  }
}

# -------------------------- Autocompletion ------------------------
# Custom completions for external commands (those outside of Nushell)
# Each completions has two parts: the form of the external command, including its flags and parameters
# and a helper command that knows how to complete values for those flags and parameters
#
# This is a simplified version of completions for git branches and git remotes
def "nu-complete git branches" [] {
  ^git branch | lines | each { |line| $line | str find-replace '\* ' '' | str trim }
}

def "nu-complete git remotes" [] {
  ^git remote | lines | each { |line| $line | str trim }
}

extern "git co" [
  branch?: string@"nu-complete git branches" # name of the branch to checkout
  ...files?: string                          # the file(s) to checkout
  -b: string                                 # create and checkout a new branch
  -B: string                                 # create/reset and checkout a branch
  -l                                         # create reflog for new branch
  --guess                                    # second guess 'git checkout <no-such-branch>' (default)
  --overlay                                  # use overlay mode (default)
  --quiet(-q)                                # suppress progress reporting
  --recurse-submodules: string               # control recursive updating of submodules
  --progress                                 # force progress reporting
  --merge(-m)                                # perform a 3-way merge with the new branch
  --conflict: string                         # conflict style (merge or diff3)
  --detach(-d)                               # detach HEAD at named commit
  --track(-t)                                # set upstream info for new branch
  --force(-f)                                # force checkout (throw away local modifications)
  --orphan: string                           # new unparented branch
  --overwrite-ignore                         # update ignored files (default)
  --ignore-other-worktrees                   # do not check if another worktree is holding the given ref
  --ours(-2)                                 # checkout our version for unmerged files
  --theirs(-3)                               # checkout their version for unmerged files
  --patch(-p)                                # select hunks interactively
  --ignore-skip-worktree-bits                # do not limit pathspecs to sparse entries only
  --pathspec-from-file: string               # read pathspec from file
]

extern "git push" [
  remote?: string@"nu-complete git remotes", # the name of the remote
  refspec?: string@"nu-complete git branches"# the branch / refspec
  --verbose(-v)                              # be more verbose
  --quiet(-q)                                # be more quiet
  --repo: string                             # repository
  --all                                      # push all refs
  --mirror                                   # mirror all refs
  --delete(-d)                               # delete refs
  --tags                                     # push tags (can't be used with --all or --mirror)
  --dry-run(-n)                              # dry run
  --porcelain                                # machine-readable output
  --force(-f)                                # force updates
  --force-with-lease: string                 # require old value of ref to be at this value
  --recurse-submodules: string               # control recursive pushing of submodules
  --thin                                     # use thin pack
  --receive-pack: string                     # receive pack program
  --exec: string                             # receive pack program
  --set-upstream(-u)                         # set upstream for git pull/status
  --progress                                 # force progress reporting
  --prune                                    # prune locally removed refs
  --no-verify                                # bypass pre-push hook
  --follow-tags                              # push missing but relevant tags
  --signed: string                           # GPG sign the push
  --atomic                                   # request atomic transaction on remote side
  --push-option(-o): string                  # option to transmit
  --ipv4(-4)                                 # use IPv4 addresses only
  --ipv6(-6)                                 # use IPv6 addresses only
]

extern "git difff" [
  src?: string@"nu-complete git branches",    # the source branch
  dest?: string@"nu-complete git branches"    # the dest branch / refspec
  --patch(-p)                                 # Generate patch
  --no-patch(-s)                              # Suppress diff output.
  --output                                    # Output to a specific file instead of stdout.
  --raw                                       # Generate the diff in raw format.
  --summary                                   # Output a condensed summary of extended header information
  --name-only                                 # Show only names of changed files.
  --binary                                    # Output a binary diff that can be applied with git-apply.
  --abbrev                                    # Show the shortest prefix that is at least <n> hexdigits long
]

# def "nu-complete just cmd" [] {
#     ^just --justfile ~/.justfile --summary | split row ' '
# }

# extern "just" [
#   ' ': string@"nu-complete just cmd"
#   -f: bool      # do a force push
# ]

# -------------------- Nushell Configs -------------------------
# The default config record. This is where much of your global configuration is setup.
let default_theme = {
  # color for nushell primitives
  separator: white
  leading_trailing_space_bg: { attr: b }
  header: green_bold
  empty: blue
  bool: white
  int: white
  filesize: white
  duration: white
  date: white
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

  # shapes are used to change the cli syntax highlighting
  shape_garbage: { fg: "#FFFFFF" bg: "#FF0000" attr: b}
  shape_bool: light_cyan
  shape_int: purple_bold
  shape_float: purple_bold
  shape_range: yellow_bold
  shape_internalcall: cyna_bold
  shape_external: cyan
  shape_externalarg: green_bold
  shape_literal: blue
  shape_operator: yellow
  shape_signature: green_bold
  shape_string: green
  shape_string_interpolation: cyan_bold
  shape_list: cyan_bold
  shape_table: blue_bold
  shape_record: cyan_bold
  shape_block: blue_bold
  shape_filepath: cyan
  shape_globpattern: cyan_bold
  shape_variable: purple
  shape_flag: blue_bold
  shape_custom: green
  shape_nothing: light_cyan
}

let $config = {
  filesize_metric: $false
  use_ls_colors: true
  rm_always_trash: $false
  color_config: $default_theme
  use_grid_icons: true
  footer_mode: "25" # always, never, number_of_rows, auto
  table_mode: light # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
  quick_completions: true  # set this to $false to prevent auto-selecting completions when only one remains
  animate_prompt: $false # redraw the prompt every second
  float_precision: 2
  use_ansi_coloring: true
  filesize_format: "b" # b, kb, kib, mb, mib, gb, gib, tb, tib, pb, pib, eb, eib, zb, zib, auto
  edit_mode: emacs # emacs, vi
  max_history_size: 10000
  log_level: trace
  menu_config: {
    columns: 4
    col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
    col_padding: 2
    text_style: green
    selected_text_style: green_reverse
    marker: "| "
  }
  history_config: {
   page_size: 10
   selector: ":"
   text_style: green
   selected_text_style: green_reverse
   marker: "? "
  }
  keybindings: [
    {
      name: fzf
      modifier: control
      keycode: char_f
      mode: emacs
      event: [
        { edit: { cmd: clear } }
        { edit: { cmd: insertstring value: 'cd (ls | where type == dir | each {|it| $it.name} | str collect (char nl) | fzf | decode utf-8 | str trim)' } }
        { send: enter }
      ]
    },
    {
      name: cargo_test
      modifier: control
      keycode: char_t
      mode: emacs
      event: [
        { edit: { cmd: clear } }
        { edit: { cmd: insertString value: "cargo test --all --all-features" } }
        { send: enter }
      ]
    },
    {
        name: reload_config
        modifier: control
        keycode: char_r
        mode: emacs
        event: [
            { edit: { cmd: clear } }
            { edit: { cmd: insertString value: $"source '($nu.config-path)'" } }
            { send: Enter }
        ]
    }
  ]
}

# -------------------- Custom Commands -------------------------

def cls [] { ansi cls }
def 'env exists?' [] { $in in (env).name }
def sum [] { reduce {|acc, item| $acc + $item } }
def ver [] { (version | transpose key value | to md --pretty) }

def un-doced [] {
  $nu.scope.commands |
    where ($it.examples | length) == 0 && is_custom == $false && category != deprecated && is_plugin == $false && is_extern == $false |
    get command |
    where $it in [date, from, hash, into, keybindings, math, path, random, roll, split, str, to, url, dfr] == $false
}

def cargo-ile [] {
  fd -I shadow.rs | lines | each {|it| rm $it } | flatten
  cargo install --features=extra --path .
}

def cargo-ta  [] { cargo test --all --all-features }

def cargo-clippy [] {
    cargo clippy --all --all-features -- -D warnings -D clippy::unwrap_used -A clippy::needless_collect
}

# example usage: `$nu.config-path | goto`
def-env goto [] {
    let input = $in
    let path = if ($input | path type) == file { ($input | path dirname) } else { $input }
    cd $path
}

