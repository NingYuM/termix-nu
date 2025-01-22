#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/11 23:33:03
# Usage:
#   t git-remote-branch
#   t git-remote-branch origin
#   t git-remote-branch origin -t

use ../utils/git.nu [append-desc]
use ../utils/common.nu [ECODE, has-ref, hr-line, windows?]

const DEFAULT_KEEP_BRANCHES = [main master develop release/latest release/develop]

# Creates a table listing the remote branches of
# a git repository and the time of the last commit
export def git-remote-branch [
  remote: string = 'origin',  # The remote name of git repo, default is 'origin'
  --show-tags(-t),            # Show all the tags
  --clean(-c),                # Clean merged branches
  --main-branch(-m): string,  # The base main branch to check merge status
] {

  let start = date now
  $env.config.table.mode = 'light'
  cd $env.JUST_INVOKE_DIR
  let remoteUrl = git remote get-url $remote
  let nameIdx = $remoteUrl | str index-of -e '/'
  let repoName = $remoteUrl | str substring ($nameIdx + 1).. | str trim
  git fetch $remote -p
  let mainBranch = if (has-ref master) { 'master' } else if (has-ref main) { 'main' } else { 'develop' }
  let mainBranch = if ($main_branch | is-empty) { $mainBranch } else { $main_branch }
  if $clean {
    print $'Delete the branches that have been merged to (ansi gb)($mainBranch)(ansi reset) from remote (ansi gb)($remote)(ansi reset):'
  } else {
    print $'(char nl)Branches of (ansi gb)($repoName)(ansi reset) for remote ($remote)(char nl)'
  }

  mut basic = git ls-remote --heads --refs $remote | lines | par-each -k { str substring 52.. } | wrap name

  $basic = $basic | enumerate | par-each {|b|
    update item (
      $b.item |
        | upsert local { |it|  if (has-ref $it.name) { '   √' }}
        | upsert author { |it| git show $'remotes/($remote)/($it.name)' -s --format='%an' | str trim }
        | upsert merged { |it| $it.name | is-merged $remote --main-branch $mainBranch }
        | upsert SHA {|it| do -i { git rev-parse $'($remote)/($it.name)' | str substring 0..<9 } }
        | upsert last-commit { |it| git show $'remotes/($remote)/($it.name)' --no-patch --format=%ci | into datetime }
      )
  } | get item

  if $clean {
    remove-remote-branches ($basic | where merged == '√' and name not-in $DEFAULT_KEEP_BRANCHES | sort-by last-commit | get name) $remote
    return
  }
  print (append-desc $basic)
  let end = date now
  print $'(char nl)Total time cost: ($end - $start)'
  if (not $show_tags) { exit $ECODE.SUCCESS }

  print $'Tags of (ansi gb)($repoName)(ansi reset) for remote ($remote)'; hr-line
  git ls-remote --tags -q --sort="-v:refname"
    | lines
    | where $it !~ '{}'
    | str join "\n"
    | str replace -a 'refs/tags/' ''
    | detect columns -n
    | rename SHA tag
    | move tag --before SHA
    | upsert SHA { |it| str substring 0..<9 }
}

# 检查分支是否已合并到主分支（main/master）
def is-merged [
  remote: string = 'origin',  # The remote name of git repo, default is 'origin'
  --main-branch(-m): string,  # The base main branch to check merge status
] {
  let branch = $in
  # 获取远程分支和主分支的最新 commit
  let mainCommit = git rev-parse $main_branch
  let branchCommit = git rev-parse $'($remote)/($branch)'
  # 获取两个分支的共同祖先
  let mergeBase = try { git merge-base $'($remote)/($branch)' $main_branch } catch { '' }
  # 如果共同祖先等于远程分支的 commit，或者主分支包含远程分支的 commit，说明远程分支已经被合并
  # 即：远程分支是主分支的祖先 或者两个分支指向同一个提交
  if ($mergeBase == $branchCommit) or ($mainCommit == $branchCommit) { '√' } else { '' }
}

# Select the branches to remove from remote repo
def remove-remote-branches [branches: list, remote: string = 'origin'] {
  if ($branches | is-empty) { print $'(ansi grey66)No branch to remove, Bye...(ansi reset)'; return }
  let prompt = $'Press (ansi g)`a`(ansi reset) to toggle all selections, Abort with (ansi g)`esc`(ansi reset) or (ansi g)`q`(ansi reset)'
  let selected = $branches | input list --multi $prompt
  if ($selected | is-empty) { print $'(ansi grey66)Operation cancelled...(ansi reset)' }
  for b in $selected {
    print $'Removing branch (ansi gb)($b)(ansi reset)...'
    git push $remote --delete $b
  }
}

# $env | transpose
# git-remote-branch $env.JUST_INVOKE_DIR $env.REMOTE_ALIAS
