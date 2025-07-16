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
  match: string,              # The commit SHA or the commits that contain the keyword to pick
  --all(-a),                  # Show error picks of `MERGE_IGNORED` and `EMPTY_COMMIT`
  --verbose(-v),              # Show more picking details
  --list-only(-l),            # List the matched commits only without actually picking them.
  --from(-f): string,         # The source branch to pick from
  --to(-t): string,           # The target branch to pick to
  --since(-s): string,        # Filter commits since the specified date, e.g. 2025/01/12 or 2025-01-12
  --until(-u): string,        # Filter commits until the specified date, e.g. 2025/03/12 or 2025-03-12
  --ignore-file(-i): string,  # The file that contains the commit SHAs or messages to ignore
] {
  $env.config.table.mode = 'light'
  let options = get-valid-options $match --from $from --to $to --since $since --until $until --ignore-file $ignore_file
  let remoteBranch = git for-each-ref --format='%(upstream:short)' refs/heads/($options.to)
  let diffCount = git rev-list --left-right --count $'($options.to)...($remoteBranch)' | detect columns -n | rename ahead behind | get -o 0
  let countTip = if ($diffCount.ahead? | into int) > 0 { $'[AHEAD: ($diffCount.ahead)]' } else { '' }
  if $list_only and ($options.matches | length) > 0 {
    print $'(char nl)The following commits from (ansi g)($options.from)(ansi rst) need to be picked to (ansi g)($options.to) ($countTip)(ansi rst)'
    hr-line
    get-commits $options.matches | reject error | print; exit $ECODE.SUCCESS
  }
  if ($options.matches | is-empty) and $verbose {
    print $'No. matched commits of (ansi g)($match)(ansi rst) found from (ansi g)($options.from)(ansi rst) need to be picked to (ansi g)($options.to) ($countTip)(ansi rst)'
  }
  if ($options.matches | is-not-empty) and $verbose {
    print $'All matched commits of (ansi g)($match)(ansi rst) found from (ansi g)($options.from)(ansi rst) have been  picked to (ansi g)($options.to)(ansi rst)'
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
      do -i { LANG=en_US git cherry-pick --abort | complete }
      let error = if ($cherryPick.stderr =~ '--allow-empty') {
          'EMPTY_COMMIT'
        } else if ($cherryPick.stderr =~ 'conflict') {
          'CONFLICT_FOUND'
        } else if ($cherryPick.stderr =~ 'no -m option was given') {
          'MERGE_IGNORED'
        } else { 'UNKNOWN_ERROR' }

      if $error not-in [EMPTY_COMMIT MERGE_IGNORED] {
        $failedPick ++= [{ sha: $c.sha, error: $error }]
      } else if $all {
        $failedPick ++= [{ sha: $c.sha, error: $error }]
      }
      continue
    }
    $pickedCount += 1
  }

  if $pickedCount > 0 {
    print $'(char nl)Successfully picked (ansi g)($pickedCount)(ansi rst) commits from (ansi g)($options.from)(ansi rst) to (ansi g)($options.to)(ansi rst)'
  }
  if ($failedPick | is-empty) { return }
  print $'(char nl)Failed to pick the following commits from (ansi g)($options.from)(ansi rst) to (ansi g)($options.to) ($countTip)(ansi rst)'; hr-line
  get-commits $failedPick | print
}

# Get the commits information from a list of commit SHAs.
def get-commits [commits: list] {
  $commits | upsert commit {|it| get-commit-meta $it.sha } | select -o commit error | flatten
}

# Get the commit meta information from a commit SHA.
def get-commit-meta [sha: string] {
  git show $sha -s --format='%h---%s---%an---%ci'
    | split column '---'
    | rename sha msg author commitAt
    | first
    | update commitAt {|it| $it.commitAt | into datetime | format date '%m/%d %H:%M:%S' }
}

# Get the valid options for the git-pick command, exit if any option is invalid.
def get-valid-options [
  match: string,              # The commit SHA or the commits that contain the keyword to pick
  --from(-f): string,         # The source branch to pick from
  --to(-t): string,           # The target branch to pick to
  --since(-s): string,        # Filter commits since the specified date, e.g. 2025/01/12
  --until(-u): string,        # Filter commits until the specified date, e.g. 2025/03/12
  --ignore-file(-i): string,  # The file that contains the commit SHAs or messages to ignore
] {
  const MIN_SHA_WIDTH = 7
  let branches = git branch --list --format='%(refname:short)' | lines
  let to = if ($to | is-empty) { git branch --show-current | str trim } else { $to }
  let from = if ($from | is-empty) { git branch --show-current | str trim } else { $from }
  if ($from | is-not-empty) and ($from not-in $branches) {
    print -e $'Source branch (ansi r)($from)(ansi rst) not found, make sure you have checked out it from the remote.'
    exit $ECODE.INVALID_PARAMETER
  }
  if ($to | is-not-empty) and ($to not-in $branches) {
    print -e $'Dest branch (ansi r)($to)(ansi rst) not found, make sure you have checked out it from the remote.'
    exit $ECODE.INVALID_PARAMETER
  }
  # 只有输入的字符串长度大于 7 的时候才会尝试判断是不是 commit SHA
  mut matches = if ($match | str stats | get chars) >= $MIN_SHA_WIDTH { $match | split row ',' | where { has-ref $in } | wrap sha } else { [] }
  let ignore = $env.GIT_PICK_IGNORE? | default []
  let hasIgnoreFile = ($ignore_file | is-not-empty) and ($ignore_file | path exists)
  let ignoreFromFile = if $hasIgnoreFile { open -r $ignore_file | from toml | get GIT_PICK_IGNORE? | default [] } else { [] }
  let ignore = ($ignore | append $ignoreFromFile)
  # If no matches found, try to match the keyword in commit messages.
  if ($matches | is-empty) {
    let sinceOption = if ($since | is-not-empty) { $'--since=($since)T00:00:00Z' }
    let untilOption = if ($until | is-not-empty) { $'--until=($until)T23:59:59Z' }
    let sourceArgs = [$from --oneline $'--grep=($match)' --format=%H---%s---%ci $sinceOption $untilOption] | compact
    let targetArgs = [$to --oneline $'--grep=($match)' --format=%H---%s $sinceOption $untilOption] | compact
    let sourceMatches = git log ...$sourceArgs | lines | split column '---' | rename sha msg date
    let targetMatches = git log ...$targetArgs | lines | split column '---' | rename sha msg
    $matches = ($sourceMatches
      | where {|it| ($it.msg not-in $targetMatches.msg) and (($it.sha | str substring ..<8) not-in $ignore) and ($it.msg not-in $ignore) }
      | sort-by date
      | select sha
    )
  }
  { from: $from, to: $to, matches: $matches }
}
