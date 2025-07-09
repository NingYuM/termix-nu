#!/usr/bin/env nu

let starCount = (http get https://api.github.com/repos/nushell/nushell | get stargazers_count)
let downloads = (
    http get https://api.github.com/repos/nushell/nushell/releases/latest
        | get assets
        | select name download_count
        | sort-by download_count -r
)

print $'(char nl)(ansi g)Current Star Count:(ansi rst) ($starCount)'
print $'(char nl)Current Download Stats(char nl)'
$downloads
