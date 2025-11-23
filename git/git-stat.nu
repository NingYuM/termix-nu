#!/usr/bin/env nu
# Author: hustcer
# Created: 2022/06/13 17:05:20
# Usage:
#   t git-stat
#   t git-stat -a wuu -c 300 -s -e pnpm-lock.yaml

use ../utils/common.nu [hr-line]

# Show insertions/deletions and number of files changed for each commit
@example '统计最近 20 次提交的代码变更情况' {
  t git-stat
} --result '显示每次提交的增删行数及文件数'
@example '统计指定作者 `hustcer` 最近 10 次提交的变更情况' {
  t git-stat -a hustcer -c 10
}
@example '统计最近 20 次提交的变更情况并显示汇总信息' {
  t git-stat -s
}
@example '仅显示最近 20 次提交的汇总变更信息（不显示每次提交详情）' {
  t git-stat --summary-only
}
@example '统计变更情况时排除 `pnpm-lock.yaml` 文件' {
  t git-stat -e pnpm-lock.yaml
}
@example '统计 2025 年 1 月份的代码变更情况' {
  t git-stat -f 2025/01/01 -t 2025/01/31
}
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
      let diff_output = git diff ...$args
      let diff = if ($diff_output | str length) == 0 {
        []
      } else {
        $diff_output
          | detect columns -n
          | rename insertions deletions file
          | default 0 deletions
          | default 0 insertions
      }

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

  if not $summary_only { $stat | reject -o file | print }

  if not ($summary or $summary_only) { return }
  mut total = $stat
    | reduce --fold { fileChanged: 0, insertions: 0, deletions: 0 } { |acc x|
        {
          deletions: ($acc.deletions + $x.deletions),
          insertions: ($acc.insertions + $x.insertions),
          fileChanged: ($acc.fileChanged + $x.fileChanged),
        }
      }

  $total.commits = $stat.commit | uniq | length
  $total.uniqFileChanged = $stat.file | flatten | uniq | length
  $total = $total | select commits deletions insertions fileChanged uniqFileChanged
  if $json { return ($total | to json) }
  print $'(char nl)Total Summary: '; hr-line 69
  $total | print
}
