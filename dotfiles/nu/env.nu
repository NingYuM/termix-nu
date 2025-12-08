# Nushell Environment Config File
#
# version = 0.100.0

# ----------------------- Begin customization -----------------------
$env.GPG_TTY = (tty)
$env.PNPM_HOME = $'($nu.home-dir)/Library/pnpm'
$env.ANDROID_HOME = $'($nu.home-dir)/Library/Android/sdk'
$env.HOMEBREW_BOTTLE_DOMAIN = 'https://mirrors.ustc.edu.cn/homebrew-bottles/bottles'

$env.XDG_CONFIG_HOME = $'($nu.home-dir)/.config'
$env.CODEX_HOME = $'($nu.home-dir)/.config/codex'

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
    | prepend $'($nu.home-dir)/.local/bin'
    | prepend '/usr/local/bin'
    | prepend '/opt/homebrew/bin'
    | prepend '/Library/TeX/texbin'
    | prepend '/usr/local/opt/ruby/bin'
    | prepend $'($nu.home-dir)/.bun/bin'
    | prepend $'($nu.home-dir)/.moon/bin'
    | prepend $'($nu.home-dir)/.cargo/bin'
    | append `/Applications/Ghostty.app/Contents/MacOS/`
    | append $'($nu.home-dir)/Library/Android/sdk/platform-tools'
)

if not (which fnm | is-empty) {
  ^fnm env --json | from json | load-env

  $env.PATH = $env.PATH | prepend ($env.FNM_MULTISHELL_PATH | path join (if $nu.os-info.name == 'windows' { '' } else { 'bin' }))
  $env.config.hooks.env_change.PWD = (
    $env.config.hooks.env_change.PWD? | append {
      condition: {|| ['.nvmrc' '.node-version', 'package.json'] | any {|el| $el | path exists }}
      code: {|| ^fnm use }
    }
  )
}

# ENV_CONVERSIONS
# ---------------
# Certain variables, such as those containing multiple paths, are often stored as a
# colon-separated string in other shells. Nushell can convert these automatically to a
# more convenient Nushell list.  The ENV_CONVERSIONS variable specifies how environment
# variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running external commands (to_string)
#
# Note: The OS Path variable is automatically converted before env.nu loads, so it can
# be treated a list in this file.
#
# Note: Environment variables are not case-sensitive, so the following will work
# for both Windows and Unix-like platforms.
#
# By default, the internal conversion looks something like the following, so there
# is no need to add this in your actual env.nu:
$env.ENV_CONVERSIONS = {
    "Path": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}

# Here's an example converts the XDG_DATA_DIRS variable to and from a list:
$env.ENV_CONVERSIONS = $env.ENV_CONVERSIONS | merge {
    "XDG_DATA_DIRS": {
        from_string: { |s| $s | split row (char esep) | path expand --no-symlink }
        to_string: { |v| $v | path expand --no-symlink | str join (char esep) }
    }
}

#
# Other common directory-lists for conversion: TERMINFO_DIRS.
# Note that other variable conversions take place after `config.nu` is loaded.

# NU_LIB_DIRS
# -----------
# Directories in this constant are searched by the
# `use` and `source` commands.
#
# By default, the `scripts` subdirectory of the default configuration
# directory is included:
const NU_LIB_DIRS = [
    ($nu.default-config-dir | path join 'scripts') # add <nushell-config-dir>/scripts
    ($nu.data-dir | path join 'completions') # default home for nushell completions
]
# You can replace (override) or append to this list by shadowing the constant
const NU_LIB_DIRS = $NU_LIB_DIRS ++ [($nu.default-config-dir | path join 'modules')]

# An environment variable version of this also exists. It is searched after the constant.
$env.NU_LIB_DIRS ++= [ ($nu.data-dir | path join "lib") $'($env.HOME)/.config/nushell/lib' ]

# NU_PLUGIN_DIRS
# --------------
# Directories to search for plugin binaries when calling add.

# By default, the `plugins` subdirectory of the default configuration
# directory is included:
const NU_PLUGIN_DIRS = [
    ($nu.default-config-dir | path join 'plugins') # add <nushell-config-dir>/plugins
]
# You can replace (override) or append to this list by shadowing the constant
const NU_PLUGIN_DIRS = $NU_PLUGIN_DIRS ++ [($nu.default-config-dir | path join 'plugins')]

# As with NU_LIB_DIRS, an $env.NU_PLUGIN_DIRS is searched after the constant version
