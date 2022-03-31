#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/03/31 15:20:20
# Description: Source line counter for nu

# Counting all nushell lines:
# let total = (ls **/*.nu | length)
# let lines = (ls **/*.nu | each { |it| wc -l $it.name } | detect columns -n | rename lines file | get lines | each {|it| $it | into int } | math sum)
# let avg = ($lines / $total | math round)

def 'nu-sloc' [] {
    let stats = (
        ls **/*.nu | each { |it| wc -l $it.name }
            | detect columns -n
            | rename lines file
            | move file --before lines
            | update lines {|s| $s.lines | into int }
            | insert blank {|s| $s.lines - (open $s.file | lines | find --regex '\S' | length) }
            | insert comments {|s| open $s.file | lines | find --regex '^\s*#' | length }
            | sort-by lines -r
    )

    let lines = ($stats | reduce -f 0 {|it, acc| $it.lines + $acc })
    let blank = ($stats | reduce -f 0 {|it, acc| $it.blank + $acc })
    let comments = ($stats | reduce -f 0 {|it, acc| $it.comments + $acc })
    let total = ($stats | length)
    let avg = ($lines / $total | math round)

    $'(ansi pr) SLOC Summary for Nushell (ansi reset)'
    print { 'Total Lines': $lines, 'Blank Lines': $blank, Comments: $comments, 'Total Nu Scripts': $total, 'Avg Lines/Script': $avg }
    $'Source file stat detail:'
    print $stats
}

def main [] {
    nu-sloc
}
