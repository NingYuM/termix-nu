#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/05 19:39:56
# Description: Install mac CLI Apps
# Usage:
#   nu actions/setup-mac.nu

let termixConf = (open 'termix.toml' | to json)

def setup-mac [] {
    if (is-installed brew) {
        print $'Prepare to use `brew` to install CLI apps...(char nl)(char nl)'
    } else {
        print $'You should install `brew` and try again..., bye!(char nl)'
        exit 2
    }

    # brew update
    echo [
        (brew-inst ripgrep,zoxide,just,mcfly,fnm,fd)
    ] | flatten
}

# Check if a CLI App was installed, return true if installed, otherwise return false
def is-installed [
  app: string     # The CLI App to check
] {
  let bin = ($termixConf | query json $'macCliApps.($app).bin')
  let check = if ($bin | is-empty) { $app } else { $bin }
  let installed = (which $check | length) > 0
  $installed
}

def brew-inst [
    apps: string    # The cli apps to install, separated by ','
] {
    $apps | split row ',' | each { |app|
        [
            ($'($app) is installed ?' | fill -a l -w 30 -c '.')
            (is-installed $app | into string)
        ] | str join
    }
}

setup-mac
