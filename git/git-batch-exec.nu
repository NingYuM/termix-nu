#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/15 11:39:56
# Usage:
#   t git-batch-exec 'git reset --hard HEAD~3'
#   t git-batch-exec 'git show --abbrev-commit --no-patch'

use ../utils/compose-cmd.nu [compose-command]
use ../utils/common.nu [ECODE get-env hr-line has-ref]

# git reset --hard HEAD~3
# git show --abbrev-commit --no-patch

# 在候选分支上批量执行特定操作,多个分支用英文`,`分隔
export def 'git batch-exec' [
  cmd: string,        # The command to execute for specified branches
  branches?: string,  # The branches to have command be executed, default all local branches
] {

  # echo $cmd; echo $branches; exit $ECODE.SUCCESS
  let dest = $branches | str trim | split row ',' | compact
  # fix: 'fatal: not a git repository (or any of the parent directories): .git'
  cd $env.JUST_INVOKE_DIR
  let current = git branch --show-current | str trim
  let cmdToExec = compose-command $cmd

  # 如果有远程分支不存在会出错
  # let available = (git for-each-ref --format='%(refname:short)' refs/heads | lines)
  # Fix `^^^^^ requires string input issue at 'lines'`
  let available = (git branch | into string | lines | par-each -k { str substring 2.. })
  let candidates = if ($branches | is-empty) { $available } else { $dest }

  print $'(char nl)Start to run (ansi r)“($cmdToExec)”(ansi reset) on branches: (char nl)'
  print ($candidates | wrap name)

  print $"(char nl)Current branch: ($current)"
  let statusCheck = (git status --porcelain)
  if not ($statusCheck | is-empty) {
    git stash save 'Stash before running git-batch-exec'
  }

  $candidates | each { |branch|
    if (has-ref $branch) {
      git checkout $branch
      # Execute cmd here
      nu -c $cmdToExec
      hr-line
    } else {
      print $'Branch (ansi r)($branch) (ansi reset)not available...(char nl)'
    }
  }
  git checkout $current
  if not ($statusCheck | is-empty) { git stash pop }
}
