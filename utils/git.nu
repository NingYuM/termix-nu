#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/31 10:05:20
# Usage:
#   Git related helpers

# Do a git repo sync
def 'do-sync' [
  syncFrom: string  # The git branch or commit hash to sync from
  gitUrl: string    # The remote git repo url
  repo: any         # The git repo config options
] {
  print $'Sync from local (ansi g)($syncFrom)(ansi reset) to remote (ansi p)($repo.dest) of repo ($repo.repo)(ansi reset) -->(char nl)'
  let force = (get-env FORCE '0' | into int)
  let forcePush = (get-env FORCE_PUSH '0' | into int)
  let hasLock = (do -i { $repo | get lock }) != $nothing
  if ($forcePush == 1 || $force == 1 || $hasLock) {
    # You MUST use '--no-verify' to prevent infinit loops!!!
    git push --no-verify --force $gitUrl $'($syncFrom):refs/heads/($repo.dest)'
  } else {
    git push --no-verify $gitUrl $'($syncFrom):refs/heads/($repo.dest)'
  }
}

# 1. 无`lock`字段直接返回待同步分支名
# 2. 有`lock`字段:
#    A.  如果 lock == 'true' 则无须同步
#    B.  如果 lock != 'true' 且该字段为有效的 git commit hash 则以该hash对应的commit为待同步源
#    C.  如果 lock != 'true' 且该字段不是有效的 git commit hash 则无须同步
# 获取待同步分支或者 Commit ID
def 'get-sync-ref' [
  syncFrom: string  # The git branch or commit hash to sync from
  repo: any         # The git repo config options
] {
  let hasLock = (do -i { $repo | get lock }) != $nothing
  if $hasLock {
    if $repo.lock == 'true' { $nothing } else {
      if (has-ref $repo.lock) { $repo.lock } else { $nothing }
    }
  } else {
    $syncFrom
  }
}

# Append the `has-desc` column to a git summary table to indicate if that branch has a description
def 'append-desc' [
  records: table    # The table to append a `has-desc` column witch must has a `name` column for the git branch name
] {

  let descFile = 'd.toml'
  let localIExists = (has-ref i)
  let remoteIExists = (has-ref origin/i)
  if not ($localIExists || $remoteIExists) {
    $records
  } else {
    # 本地 i 分支优先级高于远程
    let querySource = (if ($localIExists) { 'i' } else { 'origin/i' })
    let descriptions = (git show $'($querySource):($descFile)' | from toml | to json)
    let summary = (
      $records | insert has-desc { |it|
        # 处理分支名称包含‘.’的情况: `support/release-2.4`
        let escapedBranch = ($it.name | str replace -a '\.' '\.')
        let desc = ($descriptions | query json $'descriptions.($escapedBranch)')
        if ($desc | empty?) { '' } else { '   √' }
      }
    )
    $summary | move has-desc --after author | sort-by last-commit
  }
}
