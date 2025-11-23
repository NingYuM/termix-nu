#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-branch
#   t git-remote-branch origin
#   t git-remote-branch origin -t

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref, hr-line, windows?, FZF_DEFAULT_OPTS, FZF_THEME, _TIME_FMT]

const DEFAULT_KEEP_BRANCHES = ['^main$' '^master$' '^feature/latest$' '^develop$' '^release/.*']

# Listing the remote branches of a git repository and the time of the last commit, etc.
# Or remove the merged branches
export def git-remote-branch [
  remote: string = 'origin',  # The remote name of git repo, default is 'origin'
  --show-tags(-t),            # Show all the tags
  --clean(-c),                # Clean merged branches
  --main-branch(-m): string,  # The base main branch to check merge status
] {

  let start = date now
  $env.config.table.mode = 'light'
  cd ($env.JUST_INVOKE_DIR? | default $env.PWD)
  # Extract repository name from remote URL
  let remoteUrl = git remote get-url $remote
  let repoName = $remoteUrl | split row '/' | last | str trim

  git fetch $remote -p
  # Determine main branch with match pattern
  let mainBranch = $main_branch | default (
    match true {
      _ if (has-ref master) => 'master',
      _ if (has-ref main) => 'main',
      _ => 'develop'
    }
  )

  if not (has-ref $mainBranch) and not (has-ref $'($remote)/($mainBranch)') {
    print $'(ansi r)ERROR: The specified main branch (ansi gb)($mainBranch)(ansi r) does not exist locally or on remote (ansi gb)($remote)(ansi red).(ansi rst)'
    exit $ECODE.INVALID_PARAMETER
  }

  # Print header based on operation mode
  match $clean {
    true => { print $'Delete the branches that have been merged to (ansi gb)($mainBranch)(ansi rst) from remote (ansi gb)($remote)(ansi rst):' },
    false => { print $'(char nl)Branches of (ansi gb)($repoName)(ansi rst) for remote ($remote)(char nl)' }
  }

  # Fetch and parse remote branches
  let branches = (
    git ls-remote --heads --refs $remote
      | detect columns -n
      | rename sha name
      | get name
      | each { str replace 'refs/heads/' '' }
  )

  # Enrich branch information in parallel
  let basic = $branches | par-each -k {|name|
    let remoteBranch = $'remotes/($remote)/($name)'
    {
      name: $name,
      local: (if (has-ref $name) { '   √' } else { '' }),
      author: (git show -s --format='%an' $remoteBranch | str trim),
      merged: ($name | is-merged $remote --main-branch $mainBranch),
      SHA: (do -i { git rev-parse $'($remote)/($name)' | str substring 0..<9 } | default 'N/A'),
      last-commit: (git show --no-patch --format=%ci $remoteBranch | into datetime)
    }
  }

  # Handle clean mode or display branches
  if $clean {
    let mergedBranches = (
      $basic
        | where {|it| $it.merged == '√' and $it.name != $mainBranch and (not ($DEFAULT_KEEP_BRANCHES | any {|k| $it.name =~ $k }))}
        | sort-by last-commit
    )
    remove-remote-branches $mergedBranches $remote
    return
  }

  # Display branches with description
  print (append-desc $basic)
  print $'(char nl)Total time cost: ((date now) - $start)'

  # Show tags if requested
  if $show_tags {
    print $'Tags of (ansi gb)($repoName)(ansi rst) for remote ($remote)'
    hr-line
    git ls-remote --tags -q --sort="-v:refname"
      | lines
      | where $it !~ '{}'
      | str join "\n"
      | str replace -a 'refs/tags/' ''
      | detect columns -n
      | rename SHA tag
      | move tag --before SHA
      | update SHA { str substring 0..<9 }
      | table -t psql
  }
}

# Check if a branch has been merged into the main branch
def is-merged [
  remote: string = 'origin',
  --main-branch(-m): string,
] {
  let branch = $in
  let remoteBranch = $'($remote)/($branch)'

  # Resolve main branch reference (try local first, then remote)
  let mainRef = if (has-ref $main_branch) { $main_branch } else { $'($remote)/($main_branch)' }

  # 1. Fast check: Git native merge detection (ancestor check)
  let mainCommit = do -i { git rev-parse $mainRef } | complete | get stdout | str trim
  let branchCommit = do -i { git rev-parse $remoteBranch } | complete | get stdout | str trim
  if ($mainCommit | is-empty) or ($branchCommit | is-empty) { return '' }
  let mergeBase = do -i { git merge-base $remoteBranch $mainRef } | complete | get stdout | str trim
  if ($mergeBase == $branchCommit) or ($mainCommit == $branchCommit) { return '√' }

  # 2. Slow check: Patch-ID detection (for rebased/cherry-picked branches)
  # If git cherry returns lines starting with "+", it means there are commits in the branch
  # that do not have an equivalent patch-id in the main branch.
  # If it returns only "-" lines (or empty), it means all commits are effectively merged.
  # Note: This still misses "Squash Merges" where multiple commits are squashed into one with a different patch-ID.
  let cherry_check = do -i { git cherry $mainRef $remoteBranch } | complete
  if $cherry_check.exit_code == 0 {
    let unmerged = ($cherry_check.stdout | lines | any {|l| $l starts-with "+" })
    if not $unmerged { return '√' }
  }

  ''
}

# Select and remove branches from remote repository
def remove-remote-branches [
  branches: list,
  remote: string = 'origin'
] {
  # Early return if no branches
  if ($branches | is-empty) {
    print $'(ansi grey66)No branch to remove, Bye...(ansi rst)'; return
  }

  # Calculate column widths
  let max_name = $branches.name | str length | math max
  let max_author = $branches.author | str length | append 6 | math max

  # Prepare input for fzf
  let input = ($branches | each {|b|
    let date = $b.last-commit | format date $_TIME_FMT
    let name_pad = $b.name | fill -a l -c ' ' -w $max_name
    let author_pad = $b.author | fill -a l -c ' ' -w $max_author
    $"($name_pad) | ($b.SHA) | ($date) | ($author_pad)"
  } | str join (char nl))

  let header_name = "Name" | fill -a l -c ' ' -w $max_name
  let header_sha = "SHA" | fill -a l -c ' ' -w 9
  let header_date = "Date" | fill -a l -c ' ' -w 19
  let header_author = "Author" | fill -a l -c ' ' -w $max_author
  let header = $"($header_name) | ($header_sha) | ($header_date) | ($header_author)"

  # Run fzf
  const FZF_KEY_BINDING = "--bind ctrl-a:select-all,ctrl-d:deselect-all,ctrl-t:toggle-all"
  $env.FZF_DEFAULT_OPTS = $'($FZF_DEFAULT_OPTS) --header "($header)" ($FZF_THEME) ($FZF_KEY_BINDING)'
  let selected = try { $input | fzf -m --ansi | lines } catch {
    print $'(ansi red)Failed to run fzf. Please ensure fzf is installed.(ansi rst)'
    return
  }

  # Early return if cancelled
  if ($selected | is-empty) {
    print $'(ansi grey66)Operation cancelled...(ansi rst)'; return
  }

  # Extract branch names
  let removes = $selected | each {|line| $line | split row " | " | first | str trim }

  # Display branches to be deleted
  print $'(char nl)The following branches will be deleted from remote (ansi gb)($remote)(ansi rst):(char nl)'
  $removes | table -t psql | print; print -n (char nl)
  # Confirmation
  let confirm = input $'(ansi y)Are you sure you want to delete these branches? [y/N] (ansi rst)'
  if ($confirm | str downcase) != 'y' {
    print $'(ansi grey66)Operation cancelled...(ansi rst)'
    return
  }

  # Remove selected branches
  $removes | each {|branch|
    print $'Removing branch (ansi gb)($branch)(ansi rst)...'
    git push $remote --delete $branch
  }
}
