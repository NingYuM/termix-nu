#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/30 11:06:52
# Usage:
#   t repo-transfer $source-repo $dest-repo
# Ref:
#   https://github.com/nushell/nushell/issues/4396

use ../utils/common.nu [ECODE get-tmp-path hr-line]

# Transfer repo from source to dest
@example '将 Git 仓库从源仓库同步到新的目标仓库，比如：' {
  t repo-transfer https://erda.cloud/terminus/dop/t-erp/a.git https://erda.cloud/terminus/dop/t-erp/b.git
} --result '同步 a.git 仓库到 b.git 内容包括所有分支、Tags, b.git 仓库须事先创建好。该命令可以重复执行,以实现增量同步'
export def 'git-repo-transfer' [
  source: string,   # The source repo git url
  dest: string,     # The dest repo git url
] {
  let tmpPath = get-tmp-path
  cd $tmpPath
  print $'(char nl)Sync git repo from ($source)(char nl)'
  print $'to dest:      (ansi g)---> ($dest)(ansi rst)(char nl)'
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
      print -e $'(ansi r)Path ($tmpPath)/($repoName) already exists(ansi rst), Please remove it and try again...(char nl)'
      exit $ECODE.CONDITION_NOT_SATISFIED
    }
  } else {
    print $'Cloning code to: (ansi g)($tmpPath)/($repoName)(ansi rst)(char nl)'
    git clone --mirror $source $repoName; cd $repoName
    git remote set-url origin --push $dest
    do-push $dest
  }
}

# Transfer specified branches from source repo to dest repo
@example '将 Git 仓库中指定的一个或多个分支同步到新的目标仓库，比如：' {
  git-branch-transfer https://erda.cloud/terminus/dop/t-erp/a.git https://erda.cloud/terminus/dop/t-erp/b.git "main,develop"
} --result '同步 a.git 仓库中指定的分支到 b.git，保留分支历史记录'
export def 'git-branch-transfer' [
  source: string,   # The source repo git url
  dest: string,     # The dest repo git url
  branches: string  # Comma-separated branch names to transfer
] {
  let tmpPath = get-tmp-path
  cd $tmpPath
  print $'(char nl)Sync git branches from ($source)(char nl)'
  print $'to dest:      (ansi g)---> ($dest)(ansi rst)(char nl)'
  print $'branches:     (ansi g)($branches)(ansi rst)(char nl)'
  hr-line

  let nameIndexStart = $source | str index-of -e '/'
  let repoName = $'($source | str substring ($nameIndexStart + 1)..)-branch-sync'
  let exists = [$tmpPath $repoName] | path join | path exists
  let branches = $branches | split row ',' | each { str trim }

  # Use match to reduce nested if/else
  match $exists {
    true => {
      cd $repoName
      handle-existing-repo $source $dest $branches $repoName
    },
    false => {
      print $'Cloning code to: (ansi g)($tmpPath)/($repoName)(ansi rst)(char nl)'
      # Clone with depth 1 to get latest commit, but we'll fetch full history for branches
      git clone --no-checkout $source $repoName; cd $repoName
      handle-new-repo $source $dest $branches
    }
  }
}

# Handle existing repository on local disk
def handle-existing-repo [
  source: string,
  dest: string,
  branches: list<string>,
  repoName: string
] {
  # Trim is required here to make it equal to $source
  let prevFetchUrl = (git remote get-url origin | str trim)
  if ($prevFetchUrl != $source) {
    let tmpPath = get-tmp-path
    let nameIndexStart = $source | str index-of -e '/'
    let repoName = $'($source | str substring ($nameIndexStart + 1)..)-branch-sync'
    print -e $'(ansi r)Path ($tmpPath)/($repoName) already exists(ansi rst), Please remove it and try again...(char nl)'
    exit $ECODE.CONDITION_NOT_SATISFIED
  }

  print $'Repo ($repoName) already exists, just sync specified branches from source to dest.(char nl)'
  # Fetch all branches
  git fetch origin
  process-branches $branches
  git remote set-url origin --push $dest
  do-push-branches $dest $branches
}

# Handle newly cloned repository
def handle-new-repo [
  source: string,
  dest: string,
  branches: list<string>
] {
  # Fetch all branches
  git fetch origin
  process-branches $branches
  git remote set-url origin --push $dest
  do-push-branches $dest $branches
}

# Process branches - create local branches tracking remote branches
def process-branches [
  branches: list<string>
] {
  $branches | each {|branch|
    if (git branch -r | str contains $'origin/($branch)') {
      git branch -f $branch $'origin/($branch)'
    } else {
      print -e $'(ansi r)Warning: Branch ($branch) not found in remote repository.(ansi rst)(char nl)'
    }
  }
}

# Push all the repos in the local mirror to the remote dest
def do-push [
  dest: string      # The dest repo git url
] {
  print $'(ansi g)Push code to the remote dest:(ansi rst)(char nl)'
  # 当仓库不存在的时候截获标准错误流需要 `do -i {}`
  # --no-verify: Skip all pre-push and post-push hooks to avoid "fatal: this operation must be run in a work tree" error
  let push = (do -i { git push --mirror --no-verify } | complete)
  # FIXME: Nu Bug: stdout redirect to stderr
  if not ($push.stderr | is-empty) { print $push.stderr }
  if not ($push.stdout | is-empty) { print $push.stdout }
  if $push.stderr =~ 'not found' {
    print -e $'(ansi r)Error: The dest repo does not exist, please create it and try again, bye...(ansi rst)(char nl)'
  }
  if $push.exit_code == 0 {
    print $'(ansi g)Bravo! Repo transfer successfully!(ansi rst)(char nl)'
  }
}

# Push specified branches to the remote dest
def do-push-branches [
  dest: string,           # The dest repo git url
  branches: list<string>  # List of branch names to push
] {
  print $'(ansi g)Push specified branches to the remote dest:(ansi rst)(char nl)'
  let push = git push --force-with-lease --no-verify --force origin ...($branches | each {|b| $'($b):($b)'}) | complete
  # FIXME: Nu Bug: stdout redirect to stderr
  if not ($push.stderr | is-empty) { print $push.stderr }
  if not ($push.stdout | is-empty) { print $push.stdout }
  if $push.stderr =~ 'not found' {
    print -e $'(ansi r)Error: The dest repo does not exist, please create it and try again, bye...(ansi rst)(char nl)'
  }
  if $push.exit_code == 0 {
    print $'(ansi g)Bravo! Branches transfer successfully!(ansi rst)(char nl)'
  }
}
