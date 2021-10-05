# Author: hustcer
# Created: 2021/10/05 19:39:56
# Description: Install mac CLI Apps
# Usage:
#   nu actions/setup-mac.nu

let termixConf = (open 'termix.toml' | to json)

def 'setup-mac' [] {
    if (is-installed brew) {
        echo $'Prepare to use `brew` to install CLI apps...(char nl)(char nl)'
    } {
        echo $'You should install `brew` and try again..., bye!(char nl)'
        exit --now
    }

    # brew update
    minst aria2,bat,curl,dua-cli,esbuild,exa,fd,fnm,fzf,git,git-extras
    minst glances,go,hyperfine,just,loc,mcfly,mysql,neovim,nginx,node
    minst redis,ripgrep,rust,sd,siege,starship,tree,wget,zoxide,yj
}

# Check if a CLI App was installed, return $true if installed, otherwise return $false
def 'is-installed' [
  app: string     # The CLI App to check
] {
  let bin = ($termixConf | query json $'macCliApps.($app).bin')
  let check = (if ($bin | empty?) { $app } { $bin })
  let installed = ((which $check | length) > 0)
  echo $installed
}

def 'minst' [
    apps: string    # The cli apps to install, seperated by ','
] {
    $apps | split row ',' | each {|app|
        [
            ($'($app) is installed ?' | str rpad -l 30 -c '.')
            (is-installed $app | into string)
        ] | str collect
    }
}

setup-mac
