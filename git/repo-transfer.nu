#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/30 11:06:52
# Usage:
#   t repo-transfer $source-repo $dest-repo
# Ref:
#   https://github.com/nushell/nushell/issues/4396

use ../utils/common.nu [get-tmp-path hr-line]

# Transfer repo from source to dest
export def 'git repo-transfer' [
  source: string   # The source repo git url
  dest: string     # The dest repo git url
] {
  let tmpPath = get-tmp-path
  cd $tmpPath
  print $'(char nl)Sync git repo from ($source)(char nl)'
  print $'to dest:      (ansi g)---> ($dest)(ansi reset)(char nl)'
  hr-line
  let nameIndexStart = ($source | str index-of -e '/')
  let repoName = $'($source | str substring ($nameIndexStart + 1)..)-sync'
  let exists = ([$tmpPath $repoName] | path join | path exists)

  if $exists {
    cd $repoName
    # Trim is required here to make it equal to $source
    let prevFetchUrl = (git remote get-url origin | str trim)
    if ($prevFetchUrl == $source) {
      print $'Repo ($repoName) already exists, just sync code from source to dest.(char nl)'
      # git remote update
      git fetch origin -p
      git remote set-url origin --push $dest
      do-push $dest
    } else {
      print $'(ansi r)Path ($tmpPath)/($repoName) already exists(ansi reset), Please remove it and try again...(char nl)'
      exit 5
    }
  } else {
    print $'Cloning code to: (ansi g)($tmpPath)/($repoName)(ansi reset)(char nl)'
    git clone --mirror $source $repoName; cd $repoName
    git remote set-url origin --push $dest
    do-push $dest
  }
}

def 'do-push' [
  dest: string      # The dest repo git url
] {
  print $'(ansi g)Push code to the remote dest:(ansi reset)(char nl)'
  # 当仓库不存在的时候截获标准错误流需要 `do -i {}`
  let push = (do -i { git push --mirror } | complete)
  # FIXME: Nu Bug: stdout redirect to stderr
  if not ($push.stderr | is-empty) { print $push.stderr }
  if not ($push.stdout | is-empty) { print $push.stdout }
  if $push.stderr =~ 'not found' {
    print $'(ansi r)Error: The dest repo does not exist, please create it and try again, bye...(ansi reset)(char nl)'
  }
  if $push.exit_code == 0 {
    print $'(ansi g)Bravo! Repo transfer successfully!(ansi reset)(char nl)'
  }
}
