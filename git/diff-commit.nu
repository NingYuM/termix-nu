#!/usr/bin/env nu
# Author: hustcer
# Created: 2023/10/19 15:05:20
# Usage:
#   t git-diff-commit -f d3d9e66e7 -t 1d70d99b
#   t git-diff-commit -f d3d9e66e7 -t HEAD
#   t git-diff-commit -f HEAD~9 -t HEAD
#   t git-diff-commit -f develop -t feature/latest -g 'feat:'

use ../utils/common.nu [ECODE, has-ref, _TIME_FMT]

# Show commit info diff between two commits, support grep in Author,SHA,Date and Message fields
export def 'git diff-commit' [
  --from(-f): string,             # Diff from commit hash
  --to(-t): string = 'HEAD',      # Diff to commit hash
  --grep(-g): string,             # Find commits in Author,SHA,Date and Message fields by keyword
  --not-contain(-C): string,      # Exclude commits that contain specified keyword in commit message
  --exclude-shas(-H): string,     # Exclude commits by SHAs
  --exclude-authors(-A): string,  # Exclude commits by authors
] {
  if not (has-ref $from) {
    print -e $'Commit hash or ref (ansi p)($from)(ansi rst) not found'
    exit $ECODE.INVALID_PARAMETER
  }
  if not (has-ref $to) {
    print -e $'Commit hash or ref (ansi p)($to)(ansi rst) not found'
    exit $ECODE.INVALID_PARAMETER
  }

  mut diff = (
    git rev-list --ancestry-path $'($from)..($to)'
      | lines
      | par-each -k { git show -s --format=%cn---%h---%ci---%B $in | str trim }
      | split column '---'
      | rename Author SHA Date Message
      | upsert Date { |it| $it.Date | format date $_TIME_FMT }
    )
  if ($diff | is-empty) {
    print $'No modification between (ansi p)($from)(ansi rst) and (ansi p)($to)(ansi rst)'
    exit $ECODE.SUCCESS
  }

  if not ($not_contain | is-empty) {
    $diff = ($diff | where Message !~ $not_contain)
  }
  if not ($exclude_shas | is-empty) {
    let SHAs = $exclude_shas | split row ','
    $diff = ($diff | where {|it| $it.SHA not-in $SHAs })
  }
  if not ($exclude_authors | is-empty) {
    let authors = $exclude_authors | split row ','
    $diff = ($diff | where {|it| $it.Author not-in $authors })
  }
  if ($grep | is-empty) {
    print $'(char nl)Modification between (ansi p)($from)(ansi rst) and (ansi p)($to)(ansi rst): (char nl)'
    $diff
  } else {
    print $'(char nl)Modification between (ansi p)($from)(ansi rst) and (ansi p)($to)(ansi rst) contains ($grep): (char nl)'
    $diff | find $grep
  }
}
