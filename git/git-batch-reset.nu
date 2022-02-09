# Author: hustcer
# Created: 2021/09/18 18:52:19
# Usage:
#   t git-batch-reset 3
#   t git-batch-reset 3 develop master

# git reset --hard HEAD~3
# 将指定Git分支硬回滚N个commit
def 'git batch-reset' [
  count: int        # The commit count to reset for specified branches
  branches: string  # The branches to do reset, default all local branches
] {

  let dest = ($branches | str trim | split row ' ' | compact)
  if ($branches | str trim | empty?) {
    $'You did not specify any branches to do reset, bye...(char nl)'
    exit --now
  }
  # fix: 'fatal: not a git repository (or any of the parent directories): .git'
  cd $env.JUST_INVOKE_DIR
  let current = (git branch --show-current | str trim)

  # 如果有远程分支不存在会出错
  # FIXME: filter branches which does not exsit in the remote
  # let available = (git for-each-ref --format='%(refname:short)' refs/heads | lines)
  # Fix `^^^^^ requires string input issue at 'lines'`
  let available = (git branch | into string | lines | str substring (2,))
  let candidates = (if ($branches | empty?) { $available } else { $dest })

  $'(char nl)Start to (ansi r)reset ($count) commits(ansi reset) on branches: (char nl)'
  echo $candidates

  $"(char nl)Current branch: ($current)"
  let statusCheck = (git status --porcelain)
  if ($statusCheck | empty?) {} else {
    git stash save 'Stash before running git-batch-reset'
  }

  echo $candidates | each { |br|
    echo $"--------------------> (char nl)"
    if (has-ref $br) {
      git checkout $br
      bash -c $'git reset --hard HEAD~($count)'
    } else {
      echo $'Branch (ansi r)($br) (ansi reset)not available...(char nl)'
    }
  }
  git checkout $current
  if ($statusCheck | empty?) {} else { git stash pop }
}
