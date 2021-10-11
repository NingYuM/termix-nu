# Author: hustcer
# Created: 2021/10/11 19:57:20
# Ref: https://linuxize.com/post/how-to-rename-local-and-remote-git-branch/
# Usage:
#   t rename-branch old-name new-name

# Rename remote branch, and delete old branch after rename
def 'git rename-br' [
  from: string      # The old branch name to be renamed
  to: string        # The new branch name to rename to
  remote?: string   # Remote alias name, 'origin' by default
] {
  let remoteAlias = (if ($remote | empty?) { 'origin' } { $remote })
  let statusCheck = (git status --porcelain)
  let parse = (git rev-parse --verify $from)
  # Check and warn user if the dest branch exists
  let destExists = (git rev-parse --verify $to)
  # TODO, check if remote dest already exists.
  if ($destExists | empty?) {} {
    $'Dest branch (ansi r)($to)(ansi reset) already exists, please use another new name...(char nl)'
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
  git branch -m $to; git push $remoteAlias -u $to; git push $remoteAlias :$from
  if ($statusCheck | empty?) {} { git stash pop }
}
