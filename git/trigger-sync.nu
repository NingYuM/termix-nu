# Author: hustcer
# Created: 2021/12/06 19:50:20
# Usage:
#   Manually trigger code syncing to all related dests for specified branch
#   just trigger-sync
#   just trigger-sync feature/latest

# Manually trigger code syncing to all related dests for specified branch
def 'git trigger-sync' [
  branch?: string   # Local git branch/ref to push
] {

  cd $nu.env.JUST_INVOKE_DIR
  let current = (git branch --show-current | str trim)
  let selected = (if (has-ref $branch) { $branch } { $current } | str trim)
  # 从远程更新指定分支代码到本地
  if ($current == $selected) { git pull origin $selected } { git fetch origin $'($selected):($selected)' }
  # Remote branch does not exit
  if (has-ref $'origin/($selected)') {} {
    git push origin $selected -u
    exit --now
  }
  let diff = (git rev-list --left-right $'($selected)...origin/($selected)' --count | detect columns -n | rename local remote | update cells { $it | into int })
  # 如果本地分支超前于远程分支直接push就可以了，会自动触发批量同步
  if ($diff.remote == 0 && $diff.local > 0) {
    git push origin $selected
    exit --now
  } {}

  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { $selected } { 'i' })

  if (has-ref $'origin/($confBr)') {} {
    $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit --now
  }
  let pushConf = (git show $'origin/($confBr):.termixrc' | from toml | to json)
  let ignored = (get-env SYNC_IGNORE_ALIAS '')
  # 获取待同步目的仓库及目的分支映射
  let dests = ($pushConf | query json $'branches.($selected)')
  # 如果没有任何同步配置直接退出
  # FIXME: ignore `error: Coercion error`
  do -i {
    if ($dests == $nothing) { exit --now } {}
  }

  let syncDests = ($dests | insert SYNC {
      get repo | each { if ($',($ignored),' =~ $',($it),') { '   x' } { '   √' } }
    } | insert source $selected | move source --before dest | sort-by SYNC)
  # 如果没有找到对应分支的 push hook 配置则直接退出
  if (($syncDests | length) > 0) {
    $'(char nl)Found the following matched dests from (ansi g)`origin/($confBr):.termixrc`(ansi reset):(char nl)'
    echo $syncDests | default lock '-' | move lock --before SYNC
  } { exit --now }

  echo $syncDests | where SYNC == '   √' | each { |iter|
    let syncFrom = (get-sync-ref $selected $iter)
    let gitUrl = ($pushConf | query json $'repos.($iter.repo).git')
    let navUrl = ($pushConf | query json $'repos.($iter.repo).url')

    if $syncFrom == $nothing {} { do-sync $syncFrom $iter }
    if ($navUrl != '' && $syncFrom != $nothing) { ^echo $'You can check the result from: (ansi g)($navUrl)(ansi reset)\n' } { ^echo '' }
  }
  char nl
}
