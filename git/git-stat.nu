#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/06/13 17:05:20
# Usage:
#   t git-stat

# Show insertions/deletions and number of files changed for each commit
export def 'git stat' [
  repo: path,    # The repo path to show git stat
  --count(-c): int = 20,
  --author(-a): string,
] {
  print $'(ansi p)(char nl)Modification stat info for each commit: (ansi reset)(char nl)'
  cd $repo
  let log = if $author == '*' {
    (git log '--pretty=%h %aN' --no-merges -n $count)
  } else {
    (git log '--pretty=%h %aN' --no-merges -n $count --author $author)
  }
  $log
    | lines
    | split column ' ' commit name
    | upsert changes { |c|

      git diff $'($c.commit)^!' --shortstat
        | str trim
        | split row ','
        | str trim
        | split column ' '
        | get column1
        | rotate --ccw changes insertions deletions
        | default '0' deletions
        | default '0' insertions

    } | flatten -a
}
