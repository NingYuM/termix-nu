#!/usr/bin/env nu
# Author: hustcer
# Created: 2024/04/26 11:58:58
# TODO:
#   [√] Pick the commits with no conflicts automatically
#   [√] List the matched commits only without actually picking them
#   [√] List the commits that failed to be picked along with the failed reason
#   [√] Pick commits and keep the order
#   [√] Pick commits and keep the timestamp unchanged
#   [ ] Handle the same commit message in the same branch cases
# Usage:
#   t git-pick COMMIT-SHA
#   t git-pick 0330 -f release/2.5.24.0330
#   t git-pick 0330 -lf release/2.5.24.0330

use ../utils/common.nu [hr-line, has-ref, ECODE]

# Pick matched commits from one branch to another branch.
export def 'git pick' [
  match: string,        # The commit SHA or the commits that contain the keyword to pick
  --list-only(-l),      # List the matched commits only without actually picking them.
  --from(-f): string,   # The source branch to pick from
  --to(-t): string,     # The target branch to pick to
] {
  let options = get-valid-options $match --from $from --to $to
  if $list_only and ($options.matches | length) > 0 {
    print $'(char nl)The following commits from (ansi g)($options.from)(ansi reset) need to be picked to (ansi g)($options.to)(ansi reset):'
    hr-line
    get-commits $options.matches | reject error | print; exit $ECODE.SUCCESS
  }

  git checkout $options.to --quiet
  mut pickedCount = 0
  mut failedPick = []
  for c in $options.matches {
    # Get raw date with timezone from commit
    let rawDate = git show -s --format='%ct' $c.sha
    load-env { GIT_AUTHOR_DATE: $rawDate, GIT_COMMITTER_DATE: $rawDate }
    let cherryPick = do -i { git cherry-pick $c.sha | complete }
    if ($cherryPick.exit_code | into int) != 0 {
      git cherry-pick --abort
      let error = if ($cherryPick.stderr =~ '--allow-empty') {
          'EMPTY_COMMIT'
        } else if ($cherryPick.stderr =~ 'conflict') {
          'HAS_CONFLICT'
        } else { 'UNKNOWN_ERROR' }
      $failedPick = ($failedPick | append { sha: $c.sha, error: $error })
      continue
    }
    $pickedCount += 1
  }

  if $pickedCount > 0 {
    print $'(char nl)Succssfully picked (ansi g)($pickedCount)(ansi reset) commits from (ansi g)($options.from)(ansi reset) to (ansi g)($options.to)(ansi reset).'
  }
  if ($failedPick | is-empty) { return }
  print $'(char nl)Failed to pick the following commits from (ansi g)($options.from)(ansi reset) to (ansi g)($options.to)(ansi reset):'; hr-line
  get-commits $failedPick | print
}

# Get the commits information from a list of commit SHAs.
def get-commits [commits: list] {
  $commits
    | upsert commit {|it| git show $it.sha -s --format='%h---%s---%an---%ci' | split column '---' | rename sha msg author commitAt | first }
    | select -i commit error
    | flatten
}

# Get the valid options for the git-pick command, exit if any option is invalid.
def get-valid-options [
  match: string,        # The commit SHA or the commits that contain the keyword to pick
  --from(-f): string,   # The source branch to pick from
  --to(-t): string,     # The target branch to pick to
] {
  const MIN_SHA_WIDTH = 7
  let branches = git branch --list --format='%(refname:short)' | lines
  let to = if ($to | is-empty) { git branch --show-current | str trim } else { $to }
  let from = if ($from | is-empty) { git branch --show-current | str trim } else { $from }
  if ($from | is-not-empty) and ($from not-in $branches) {
    print $'Source branch (ansi r)($from)(ansi reset) not found.'
    exit $ECODE.INVALID_PARAMETER
  }
  if ($to | is-not-empty) and ($to not-in $branches) {
    print $'Destination branch (ansi r)($to)(ansi reset) not found.'
    exit $ECODE.INVALID_PARAMETER
  }
  # 只有输入的字符串长度大于 7 的时候才会尝试判断是不是 commit SHA
  mut matches = if ($match | str stats | get chars) >= $MIN_SHA_WIDTH { $match | split row ',' | filter { has-ref $in } | wrap sha } else { [] }
  # If no matches found, try to match the keyword in commit messages.
  if ($matches | is-empty) {
    let sourceMatches = git log $from --oneline --grep $match --format='%H---%s---%ci' | lines | split column '---' | rename sha msg date
    let targetMatches = git log $to --oneline --grep $match --format='%H---%s' | lines | split column '---' | rename sha msg
    $matches = ($sourceMatches | filter {|it| $it.msg not-in $targetMatches.msg } | sort-by date | select sha)
  }
  { from: $from, to: $to, matches: $matches }
}
