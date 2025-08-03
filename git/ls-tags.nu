#!/usr/bin/env nu
# Author: hustcer
# Created: 2025/08/03 19:05:20
# Usage:
#   t ls-tags
#   t ls-tags --filter v7
#   t ls-tags --sort-by time

use ../utils/common.nu [ECODE hr-line]

# List git tags with their creation date and time
export def 'list-tags' [
  --filter(-f): string = '',     # Filter tags by name
  --sort-by(-s): string = 'time' # Sort tags by tag or time
] {
  let sort = if ($sort_by != 'time') { '--sort=-v:refname' } else { '--sort=-creatordate' }
  if (git tag -l | is-empty) { exit $ECODE.SUCCESS }

  let tags = git tag --format='%(refname:strip=2)%09%(creatordate:iso)' $sort
      | detect columns -n
      | rename tag date time
      | upsert time {|e| $'($e.date) ($e.time)' }
      | select tag time

  print $'(ansi p)(char nl)Git tags: (ansi rst)'; hr-line 50
  match $filter {
    '' => $tags,
    _ if ($filter | is-not-empty) => { $tags | where tag =~ $filter }
  } | print
  print -n (char nl)
}

alias main = list-tags
