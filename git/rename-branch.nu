# Author: hustcer
# Created: 2021/10/11 19:57:20
# Ref: https://linuxize.com/post/how-to-rename-local-and-remote-git-branch/
# [√] 本地未提交变更需要 Stash 下，重命名结束 Pop;
# [ ] 旧分支本地远程都不存在给予提示;
# [ ] fatal: Needed a single revision
# [√] 本地分支不存在则远程拉取;
# [√] 新分支名称本地已存在则给予提示;
# [√] 新分支名称本地不存在但远程存在也应该给予提示;
# [√] 重命名完毕后远程删除旧分支;
# Usage:
#   t rename-branch old-name new-name

# Rename remote branch, and delete old branch after rename
def 'git rename-br' [
  from: string      # The old branch name to be renamed
  to: string        # The new branch name to rename to
  remote?: string   # Remote alias name, 'origin' by default
] {
  let remoteAlias = (if ($remote | empty?) { 'origin' } { $remote })
  git fetch $remoteAlias -p
  let statusCheck = (git status --porcelain)
  let parse = (git rev-parse --verify $from)
  # Check and warn user if the dest branch exists in local
  let destExists = (git rev-parse --verify $to)
  let destRemoteExists = (git rev-parse --verify $'($remoteAlias)/($to)')
  # Check if remote dest already exists.
  if ($destRemoteExists | empty?) {} {
    $'Dest branch (ansi r)($remote)/($to)(ansi reset) already exists in the remote, please use another new name...(char nl)'
    exit --now
  }
  if ($destExists | empty?) {} {
    $'Dest branch (ansi r)($to)(ansi reset) already exists in local, please use another new name...(char nl)'
    exit --now
  }

  # Stash here, if needed
  if ($statusCheck | empty?) {} {
    git stash save 'Stash before running git-batch-exec'
  }

  # Pull the branch to local if not exist
  if ($parse | empty?) {
    $'Branch (ansi r)($from) (ansi reset)not exist in local, will pull from remote...(char nl)'
    git checkout $'($remoteAlias)/($from)' -b $from
  } {
    git checkout $from
  }

  # Rename, push to remote and delete remote old branch
  git branch -m $to; git push $remoteAlias -u $to; git push $remoteAlias $':($from)'
  if ($statusCheck | empty?) {} { git stash pop }
}
