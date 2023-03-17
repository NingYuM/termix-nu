#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/18 18:52:19
# Usage:
#   t git-batch-reset 3
#   t git-batch-reset 3 develop master

# git reset --hard HEAD~3
# 将指定Git分支硬回滚N个commit
export def 'git batch-reset' [
  count: int        # The commit count to reset for specified branches
  branches: string  # The branches to do reset, default all local branches
] {

  let dest = ($branches | str trim | split row ' ' | compact)
  if ($branches | str trim | is-empty) {
    print $'You did not specify any branches to do reset, bye...(char nl)'
    exit --now
  }

  cd $env.JUST_INVOKE_DIR
  let current = (git branch --show-current | str trim)
  let available = (git branch | into string | lines | str substring '2,')
  let candidates = if ($branches | is-empty) { $available } else { $dest }

  print $'(char nl)Start to (ansi r)reset ($count) commits(ansi reset) on branches: (char nl)'
  print ($candidates | wrap name)

  print $"(char nl)Current branch: ($current)"
  let statusCheck = (git status --porcelain)
  if ($statusCheck | is-empty) == false {
    git stash save 'Stash before running git-batch-reset'
  }

  $candidates | each { |br|
    hr-line
    if (has-ref $br) {
      print $'Resetting ($br) ...'
      git checkout $br
      print (do { (nu -c $'^git reset --hard HEAD~($count)') })
    } else {
      print $'Branch (ansi r)($br) (ansi reset)not available...(char nl)'
    }
  }
  git checkout $current
  if ($statusCheck | is-empty) == false { git stash pop }
}
