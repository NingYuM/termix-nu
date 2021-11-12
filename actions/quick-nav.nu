# Author: hustcer
# Created: 2021/11/12 15:06:56
# Description: Quickly open the nav url in default browser, for mac only
# Usage:
#   just go

def 'go' [
    nav-key?: string  # The nav key to go from `quickNavs` config in termix.toml
] {

    let quickNavs = (open $'($nu.env.TERMIX_DIR)/termix.toml' | get quickNavs)
    if ($nav-key == '' || $nav-key == 'list') {
        $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
        $quickNavs | pivot | rename key url
        exit --now
    } {}
    let matchs = ($quickNavs | pivot | rename nav url | find $nav-key)
    # Found no match item
    do -i {
        if ($matchs == $nothing) {
            $'(ansi pb)(char nl)Available Nav Items:(char nl)(char nl)(ansi reset)'
            $quickNavs | pivot | rename key url
            exit --now
        } {}
    }

    # Found match item
    let url = ($matchs | nth 0).url
    if ($url | str starts-with 'http') {
        $'Going to open matched url: (ansi g)($url)(ansi reset) in default browser...(char nl)'
        ^open $url
    } {
        $'(ansi r)Invalid nav url, bye...(char nl)(ansi reset)'
    }
}

