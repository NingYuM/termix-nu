#!/usr/bin/env nu

let starCount = (fetch https://api.github.com/repos/nushell/nushell | get stargazers_count)
let downloads = (
    fetch https://api.github.com/repos/nushell/nushell/releases/latest
        | get assets
        | select name download_count
        | sort-by download_count -r
)

$'(char nl)(ansi g)Current Star Count:(ansi reset) ($starCount)'
$'(char nl)Current Download Stats(char nl)'
$downloads
