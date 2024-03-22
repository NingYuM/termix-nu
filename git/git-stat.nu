#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/06/13 17:05:20
# Usage:
#   t git-stat
#   t git-stat -a wuu -c 300 -s -e pnpm-lock.yaml

use ../utils/common.nu [hr-line]

# Show insertions/deletions and number of files changed for each commit
export def 'git stat' [
  --summary(-s),                # Show summary
  --count(-c): int = 20,        # Number of commits to stat
  --author(-a): string = '*',   # Author to stat
  --exclude(-e): string,        # File name to exclude, separated by comma
] {
  print $'(ansi p)(char nl)Modification stat info for each commit: (ansi reset)(char nl)'
  cd $env.JUST_INVOKE_DIR
  let log = if $author == '*' {
    (git log '--pretty=%h %aN' --no-merges -n $count)
  } else {
    (git log '--pretty=%h %aN' --no-merges -n $count --author $author)
  }
  # Use `git diff -- . ':(exclude)src/irrelevant.ts' ':(exclude)src/irrelevant2.ts'` to exclude files
  let excludes = if ($exclude | is-not-empty) { $exclude | split row ',' | wrap name | format pattern ":(exclude){name}" } else { [] }

  let stat = $log
    | lines
    | split column ' ' commit name
    | upsert changes { |c|

      let args = [$'($c.commit)^!' --shortstat ...$excludes]

      git diff ...$args
        | str trim
        | split row ','
        | str trim
        | split column ' '
        | get column1
        | rotate --ccw changes insertions deletions
        | default 0 deletions
        | default 0 insertions
        | upsert changes {|it| $it.changes | into int }
        | upsert deletions {|it| $it.deletions | into int }
        | upsert insertions {|it| $it.insertions | into int }

    } | flatten -a
  $stat | print

  if not $summary { return }
  mut total = $stat
    | reduce --fold { changes: 0, insertions: 0, deletions: 0 } { |acc x|
      {
        changes: ($acc.changes + $x.changes),
        deletions: ($acc.deletions + $x.deletions),
        insertions: ($acc.insertions + $x.insertions),
      }
    }
  $total.commits = ($stat | length)
  print $'Total Summary: '; hr-line 69
  print $total
}
