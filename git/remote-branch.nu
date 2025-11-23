#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-branch
#   t git-remote-branch origin
#   t git-remote-branch origin -t

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref, hr-line, windows?]

const DEFAULT_KEEP_BRANCHES = ['^main$', '^master$', '^develop$', '^release/.*']

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
      local: (if (do -i { has-ref $name } | default false) { '   √' } else { '' }),
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
        | where {|it| $it.merged == '√' and (not ($DEFAULT_KEEP_BRANCHES | any {|k| $it.name =~ $k }))}
        | sort-by last-commit
        | get name
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
  }
}

# Check if a branch has been merged into the main branch
def is-merged [
  remote: string = 'origin',
  --main-branch(-m): string,
] {
  let branch = $in
  # Get commits for comparison
  let mainCommit = try { git rev-parse $main_branch } catch { '' }
  let branchCommit = try { git rev-parse $'($remote)/($branch)' } catch { '' }
  let mergeBase = try { git merge-base $'($remote)/($branch)' $main_branch } catch { '' }

  # Check if branch is merged (merge-base equals branch commit or commits are identical)
  match [$mergeBase, $branchCommit, $mainCommit] {
    [$base, $branch, $main] if $base == $branch or $main == $branch => '√',
    _ => ''
  }
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

  # Prompt for branch selection
  let prompt = $'Press (ansi g)`a`(ansi rst) to toggle all selections, Abort with (ansi g)`esc`(ansi rst) or (ansi g)`q`(ansi rst)'
  let selected = $branches | input list --multi $prompt

  # Early return if cancelled
  if ($selected | is-empty) {
    print $'(ansi grey66)Operation cancelled...(ansi rst)'; return
  }

  # Remove selected branches
  $selected | each {|branch|
    print $'Removing branch (ansi gb)($branch)(ansi rst)...'
    git push $remote --delete $branch
  }
}
