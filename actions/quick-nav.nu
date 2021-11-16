# Author: hustcer
# Created: 2021/11/12 15:06:56
# Description: Quickly open the nav url in default browser, for mac only
# Usage:
#   just go

let quickNavs = (open $'($nu.env.TERMIX_DIR)/termix.toml' | get quickNavs)

def 'go' [
    nav-key?: string  # The nav key to go from `quickNavs` config in termix.toml
] {

    # If the key of `just go` is blank or list, then show all the nav items
    if ($nav-key == '' || $nav-key == 'list') { show-navs } {}
    # Find match from nav keys only
    let matchs = ($quickNavs | pivot | rename nav url | select nav | find $nav-key)
    # If no match item was found then show all the nav items
    do -i {
        if ($matchs == $nothing) { show-navs } {}
    }

    # Found match item
    let navKey = ($matchs | nth 0).nav
    let url = ($quickNavs | get ($navKey | into column_path))
    if ($url | str starts-with 'http') {
        $'Going to open matched url: (ansi g)($url)(ansi reset) in default browser...(char nl)'
        ^open $url
    } {
        $'(ansi r)Invalid nav url, bye...(char nl)(ansi reset)'
    }
}

def 'show-navs' [] {
    $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
    $quickNavs | pivot | rename key url
    exit --now
}

