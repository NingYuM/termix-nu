#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/12/06 19:50:20
# Usage:
#   Manually trigger code syncing to all related dests for specified branch
#   just trigger-sync
#   just trigger-sync -a
#   just trigger-sync feature/latest

use ../utils/git.nu [get-sync-ref do-sync]
use ../utils/common.nu [get-conf get-env has-ref hr-line]

export-env {
  # FIXME: 去除前导空格背景色
  $env.config.color_config.leading_trailing_space_bg = { attr: n }
}

# Manually trigger code syncing to all related dests for specified branch
export def 'git trigger-sync' [
  branch?: string,    # Local git branch/ref to push
  --all(-a),          # Whether to sync all branches that have syncing config
  --list(-l),         # List all branches that have syncing config
  --force(-f),        # Whether to force sync even if refused by remote
] {

  cd $env.JUST_INVOKE_DIR
  let $branch = $branch | str trim
  let ignored = get-env SYNC_IGNORE_ALIAS ''
  let current = git branch --show-current | str trim
  let selected = if ($branch | is-empty) { $current } else {
    if (has-ref $branch) { $branch } else {
      print $'Branch (ansi r)($branch)(ansi reset) does not exist, please check it again.'
      exit 7
    }
  }

  let conf = get-push-config $current --all $all | get pushConf
  let repos = $conf | query json 'repos'
  let allSyncs = $conf | query json 'branches'

  if $list {
    echo $'(char nl)The following branches have code syncing config:'; hr-line -b
    show-available-syncs $allSyncs --repos $repos --ignored $ignored
    exit 0
  }

  let candidates = if $all {
    $allSyncs | columns | filter {|it| has-ref $it }
  } else { [$selected] }

  if ($candidates | length) > 1 {
    print 'The following branches will be synced:'; hr-line
    print $candidates
  }
  for branch in $candidates {
    update-branch $branch
    sync-branch $branch --all $all --ignored $ignored --force $force
  }
}

# Show All available branch syncing configs with a readable output
def show-available-syncs [
  syncs: table,           # All available branch syncing configs
  --repos: record,        # All available repos
  --ignored(-i): string,  # 代码同步需要忽略推送的仓库简称，多个仓库用英文逗号分隔
] {
  mut results = []
  let cross = $'(ansi light_gray)  x(ansi reset)'
  let mark = $'(ansi g)  √(ansi reset)'
  for branch in ($syncs | columns) {
    for dest in ($syncs | get $branch) {
      mut sync = { Source: $branch, Dest: $'--->  ($dest.dest)', Repo: $dest.repo }
      $sync.Lock = ($dest | get -i lock | default '-')
      if ($',($ignored),' =~ $',($dest.repo),') { $sync.SYNC = $cross } else { $sync.SYNC = $mark }
      $sync.Local = if (has-ref $branch) { $mark } else { $cross }
      $sync.Remote = if (has-ref origin/($branch)) { $mark } else { $cross }
      $sync.Update = if (has-ref origin/($branch)) { git show $'origin/($branch)' --no-patch --format=%ci | into datetime }
      $results = ($results | append $sync)
    }
  }
  $results | sort-by Source | print
  print 'REPO INFO:'; hr-line
  $repos | table -e | print
  echo (char nl)
}

def update-branch [
  branch: string,    # Local git branch/ref to push
] {
  let current = git branch --show-current | str trim
  # 从远程更新指定分支代码到本地, 如果远程分支存在的话
  if (has-ref origin/($branch)) {
    if ($current == $branch) { git pull origin $branch } else { git fetch origin $'($branch):($branch)' }
  } else {
    # Remote branch does not exit
    git push origin $branch -u; exit 0
  }

  let diff = (
    git rev-list --left-right $'($branch)...origin/($branch)' --count
      | detect columns -n
      | rename local remote
      | upsert local { |it| $it.local | into int }
      | upsert remote { |it| $it.remote | into int }
  )
  # 如果本地分支超前于远程分支直接push就可以了，会自动触发批量同步
  if ($diff.remote.0 == 0 and $diff.local.0 > 0) {
    git push origin $branch
    exit 0
  }
}

def get-push-config [
  branch: string,         # Local git branch/ref to push
  --all(-a): bool,        # Whether to sync all branches that have syncing config
] {
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = get-conf useConfFromBranch
  let confBr = if $useConfBr == '_current_' { $branch } else { 'i' }
  # 如果批量同步所有分支则必须从`i`分支获取配置
  let CONF_BRANCH = if $all { 'i' } else { $confBr }

  if not (has-ref origin/($CONF_BRANCH)) {
    print $'Branch (ansi r)($CONF_BRANCH) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit 0
  }

  git fetch origin $CONF_BRANCH -q    # 更新远程分支的最新提交
  let pushConf = (git show $'origin/($CONF_BRANCH):.termixrc' | from toml | to json)
  { pushConf: $pushConf, confBr: $CONF_BRANCH }
}

def sync-branch [
  branch: string,         # Local git branch/ref to sync
  --all(-a): bool,        # Whether to sync all branches that have syncing config
  --ignored(-i): string,  # 代码同步需要忽略推送的仓库简称，多个仓库用英文逗号分隔
  --force(-f): bool,      # Whether to force sync even if refused by remote
] {

  let pushConf = get-push-config $branch --all $all
  let confBr = $pushConf.confBr
  let pushConf = $pushConf.pushConf
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = $branch | str replace -a '.' '\.'
  # 获取待同步目的仓库及目的分支映射
  let dests = $pushConf | query json $'branches.($escapedBranch)'
  # 如果没有任何同步配置直接退出
  if ($dests == null) { exit 0 }

  let syncDests = ($dests | upsert SYNC {
      get repo | each { |it| if ($',($ignored),' =~ $',($it),') { '   x' } else { '   √' } }
    } | upsert source $branch | move source --before dest | sort-by SYNC)
  # 如果没有找到对应分支的 push hook 配置则直接退出
  if ($syncDests | length) > 0 {
    print $'(char nl)Found the following matched dests from (ansi g)`origin/($confBr):.termixrc`(ansi reset):(char nl)'
    print ($syncDests | upsert lock {|it| if ('lock' in $it) { $it.lock } else { '-' }} | move lock --before SYNC)
  } else { exit 0 }

  $syncDests | where SYNC == '   √' | each { |iter|
    let syncFrom = (get-sync-ref $branch $iter)
    let gitUrl = ($pushConf | query json $'repos.($iter.repo).git')
    let navUrl = ($pushConf | query json $'repos.($iter.repo).url')

    if not ($syncFrom | is-empty) { do-sync $syncFrom $gitUrl $iter --force-sync $force }
    if ($navUrl != '' and $syncFrom != null) {
      print $'You can check the result from: (ansi g)($navUrl)(ansi reset)'
      hr-line
    }
  } | ignore # FIXME: remove ignore after `each` bug fixed
}

alias main = git trigger-sync
