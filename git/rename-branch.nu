#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/10/11 19:57:20
# Ref: https://linuxize.com/post/how-to-rename-local-and-remote-git-branch/
# [√] 本地未提交变更需要 Stash 下，重命名结束 Pop;
# [√] 旧分支本地远程都不存在给予提示;
# [√] 旧分支只有本地存在远程不存在;
# [√] 本地分支不存在则远程拉取;
# [√] 新分支名称本地已存在则给予提示;
# [√] 新分支名称本地不存在但远程存在也应该给予提示;
# [√] 重命名完毕后远程删除旧分支;

use ../utils/common.nu [ECODE has-ref hr-line]

# Rename remote branch, and delete old branch after rename
@example '将本地与远程分支 `feature/old` 重命名为 `feature/new`' {
  t rename-branch feature/old feature/new
} --result '会自动处理本地与远程分支的重命名，并删除远程旧分支'
@example '在指定远程仓库 `upstream` 上重命名分支' {
  t rename-branch feature/old feature/new upstream
}
export def 'git branch-rename' [
  from: string,               # The old branch name to be renamed
  to: string,                 # The new branch name to rename to
  remote: string = 'origin',  # Remote alias name, 'origin' by default
] {

  let remoteAlias = if ($remote | is-empty) { 'origin' } else { $remote }
  git fetch $remoteAlias -p

  let localSrcExists = has-ref $from
  let remoteSrcExists = has-ref $'($remoteAlias)/($from)'
  # Check and warn user if the dest branch exists in local
  let localDestExists = has-ref $to
  let remoteDestExists = has-ref $'($remoteAlias)/($to)'
  # Check if remote dest already exists.
  if ($remoteDestExists) {
    print -e $'Dest branch (ansi r)($remote)/($to)(ansi rst) already exists in the remote, please use another new name...(char nl)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
  if ($localDestExists) {
    print -e $'Dest branch (ansi r)($to)(ansi rst) already exists in local, please use another new name...(char nl)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }
  if not ($remoteSrcExists or $localSrcExists) {
    print -e $'Branch (ansi r)($from) (ansi rst)does not exist in both remote and local, bye...(char nl)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }

  let statusCheck = (git status --porcelain)
  # Stash here, if needed
  if not ($statusCheck | is-empty) {
    git stash save 'Stash before running git-batch-exec'
  }

  print $'(ansi g)Going to rename branch from ($from) to ($to)(ansi rst)'; hr-line
  # Pull the branch to local if not exist
  if ($localSrcExists) {
    git checkout $from
  } else {
    print $'Branch (ansi r)($from) (ansi rst)not exist in local, will pull from remote...(char nl)'
    git checkout $'($remoteAlias)/($from)' -b $from
  }
  # Rename, push to remote and ...
  git branch -m $to
  git push $remoteAlias -u $to
  # Delete remote old branch if exists
  if ($remoteSrcExists) { git push $remoteAlias $':($from)' }
  if not ($statusCheck | is-empty) { git stash pop }
}
