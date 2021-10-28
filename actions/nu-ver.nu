# Author: hustcer
# Created: 2021/10/14 10:06:56
# Description: Check the current nushell version
# Usage:
#   nu-ver

def 'nu-ver' [] {

    let currentVer = ((version).version)
    let minVer = (open $'($nu.env.TERMIX_DIR)/termix.toml' | get minNuVer)
    let m = ($minVer | split row '.' | each { $it | into int })
    let c = ($currentVer | split row '.' | each { $it | into int })
    if (($c.0 < $m.0) || ($c.1 < $m.1) || ($c.2 < $m.2)) {
        $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
        $'  Min required nu ver: (ansi r)($minVer)(ansi reset), current nu ver: ($currentVer)(char nl)'
        $'  ------------> Your nushell is (ansi r)OUTDATED(ansi reset) <------------ (char nl)'
        $'  Please run (ansi g)`brew upgrade nushell`(ansi reset) to upgrade to the latest.(char nl)'
        $'(ansi g)──────────────────────────────────────────────────────────────(ansi reset)(char nl)'
        exit --now
    } {}
}

nu-ver
