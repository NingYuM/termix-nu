#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/06/13 17:05:20
# Usage:
#   t git-stat
#   t git-stat -a wuu -c 300 -s -e pnpm-lock.yaml

use ../utils/common.nu [hr-line]

# Show insertions/deletions and number of files changed for each commit
export def 'git stat' [
  --json(-j),                   # Output in JSON format
  --summary(-s),                # Show summary
  --summary-only,               # Show summary only, no details
  --from(-f): string,           # Start time to stat in 2024/03/12 format
  --to(-t): string,             # End time to stat, current time if not specified
  --max-count(-c): int = 20,    # Number of commits to stat at most
  --author(-a): string = '*',   # Author to stat
  --exclude(-e): string,        # File name to exclude, separated by comma
] {
  $env.config.table.mode = 'light'

  if not $summary_only {
    print $'(ansi p)(char nl)Modification stat info for each commit: (ansi rst)(char nl)'
  }
  cd $env.JUST_INVOKE_DIR
  mut args = ['--pretty=%h %aN' '--no-merges']
  if $author == '*' {} else if ($author | is-not-empty) {
    $args ++= [$'--author=($author)']
  }
  if ($max_count | is-not-empty) {
    $args ++= [$'--max-count=($max_count)']
  }
  if ($from | is-not-empty) {
    $args ++= [$'--since=($from)T00:00:00Z']
  }
  if ($to | is-not-empty) {
    $args ++= [$'--until=($to)T23:59:59Z']
  }
  let log = git log ...$args
  # Use `git diff -- . ':(exclude)src/irrelevant.ts' ':(exclude)src/irrelevant2.ts'` to exclude files
  let excludes = if ($exclude | is-not-empty) {
      $exclude | split row ',' | wrap name | format pattern ":(exclude){name}"
    } else { [] }

  let stat = $log
    | lines
    | split column ' ' commit name
    | upsert changes { |c|
      let args = [$'($c.commit)^!' --numstat ...$excludes]
      let diff = git diff ...$args
                        | detect columns -n
                        | rename insertions deletions file
                        | default 0 deletions
                        | default 0 insertions

      if ($diff | is-empty) {
        { fileChanged: 0, insertions: 0, deletions: 0, file: [] }
      } else {
        $diff
          | upsert fileChanged {|it| [$it.file] | compact | length }
          # Replace '-' with 0, because some none text file diff output may have '-' in insertions/deletions
          | upsert deletions {|it| $it.deletions | str replace -a '-' 0 | into int }
          | upsert insertions {|it| $it.insertions | str replace -a '-' 0 | into int }
          | reduce --fold { fileChanged: 0, insertions: 0, deletions: 0, file: [] } { |acc x|
              {
                file: ($acc.file | append $x.file),
                deletions: ($acc.deletions + $x.deletions),
                insertions: ($acc.insertions + $x.insertions),
                fileChanged: ($acc.fileChanged + $x.fileChanged),
              }
            }
      }
    } | flatten -a

  if not $summary_only { $stat | reject file | print }

  if not ($summary or $summary_only) { return }
  mut total = $stat
    | reduce --fold { fileChanged: 0, insertions: 0, deletions: 0 } { |acc x|
        {
          deletions: ($acc.deletions + $x.deletions),
          insertions: ($acc.insertions + $x.insertions),
          fileChanged: ($acc.fileChanged + $x.fileChanged),
        }
      }

  $total.commits = ($stat.commit | uniq | length)
  $total.uniqFileChanged = ($stat.file | flatten | uniq | length)
  $total = ($total | select commits deletions insertions fileChanged uniqFileChanged)
  if $json { return ($total | to json) }
  print $'(char nl)Total Summary: '; hr-line 69
  $total | print
}
