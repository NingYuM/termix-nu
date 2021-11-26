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
# Usage:
#   t rename-branch old-name new-name

# Rename remote branch, and delete old branch after rename
def 'git branch-rename' [
  from: string      # The old branch name to be renamed
  to: string        # The new branch name to rename to
  remote?: string   # Remote alias name, 'origin' by default
] {

  let remoteAlias = (if ($remote | empty?) { 'origin' } { $remote })
  git fetch $remoteAlias -p

  let localSrcExists = (has-ref $from)
  let remoteSrcExists = (has-ref $'($remoteAlias)/($from)')
  # Check and warn user if the dest branch exists in local
  let localDestExists = (has-ref $to)
  let remoteDestExists = (has-ref $'($remoteAlias)/($to)')
  # Check if remote dest already exists.
  if ($remoteDestExists) {
    $'Dest branch (ansi r)($remote)/($to)(ansi reset) already exists in the remote, please use another new name...(char nl)'
    exit --now
  } {}
  if ($localDestExists) {
    $'Dest branch (ansi r)($to)(ansi reset) already exists in local, please use another new name...(char nl)'
    exit --now
  } {}
  if ($remoteSrcExists || $localSrcExists) {} {
    $'Branch (ansi r)($from) (ansi reset)does not exist in both remote and local, bye...(char nl)'
    exit --now
  }

  let statusCheck = (git status --porcelain)
  # Stash here, if needed
  if ($statusCheck | empty?) {} {
    git stash save 'Stash before running git-batch-exec'
  }

  # Pull the branch to local if not exist
  if ($localSrcExists) {
    git checkout $from
  } {
    $'Branch (ansi r)($from) (ansi reset)not exist in local, will pull from remote...(char nl)'
    git checkout $'($remoteAlias)/($from)' -b $from
  }

  # Rename, push to remote and ...
  git branch -m $to; git push $remoteAlias -u $to;
  # Delete remote old branch if exists
  if ($remoteSrcExists) { git push $remoteAlias $':($from)' } {}
  if ($statusCheck | empty?) {} { git stash pop }
}
