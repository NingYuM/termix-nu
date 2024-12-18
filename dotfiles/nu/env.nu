# Nushell Environment Config File
#
# version = 0.100.0

# ----------------------- Begin customization -----------------------
$env.GPG_TTY = (tty)
$env.VOLTA_HOME = $'($env.HOME)/.volta'
$env.PNPM_HOME = '/Users/hustcer/Library/pnpm'
$env.HOMEBREW_BOTTLE_DOMAIN = 'https://mirrors.ustc.edu.cn/homebrew-bottles/bottles'

# To add entries to PATH (on Windows you might use Path), you can use the following pattern:
# $env.PATH = ($env.PATH | split row (char esep) | prepend '/some/path')
# An alternate way to add entries to $env.PATH is to use the custom command `path add`
# which is built into the nushell stdlib:
# use std "path add"
# $env.PATH = ($env.PATH | split row (char esep))
# path add /some/path
# path add ($env.CARGO_HOME | path join "bin")
# path add ($env.HOME | path join ".local" "bin")
$env.PATH = (
  $env.PATH
    | split row (char esep)
    | prepend $env.PNPM_HOME
    | prepend '/usr/local/bin'
    | prepend '/opt/homebrew/bin'
    | prepend '/Library/TeX/texbin'
    | prepend $'($env.VOLTA_HOME)/bin'
    | prepend '/usr/local/opt/ruby/bin'
    | prepend $'($env.HOME)/.bun/bin'
    | prepend $'($env.HOME)/.moon/bin'
    | prepend $'($env.HOME)/.cargo/bin'
    | append `/Applications/Ghostty.app/Contents/MacOS/`
)

if not (which fnm | is-empty) {
  ^fnm env --json | from json | load-env
  # Checking `Path` for Windows
  let path = if 'Path' in $env { $env.Path } else { $env.PATH }
  let node_path = if (sys host | get name) == 'Windows' {
    $"($env.FNM_MULTISHELL_PATH)"
  } else {
    $"($env.FNM_MULTISHELL_PATH)/bin"
  }
  $env.PATH = ($path | prepend [ $node_path ])
}

$env.PATH = ($env.PATH | each {|r| $r | split row (char esep)} | flatten | uniq | str join (char esep))

# To load from a custom file you can use:
# source ($nu.default-config-dir | path join 'custom.nu')
