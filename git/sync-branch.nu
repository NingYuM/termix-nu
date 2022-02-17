# Author: hustcer
# Created: 2021/09/28 19:50:20
# Usage:
#   This's a git push hook, don't call it manually

# Sync local branches to remote according to .termixrc config file from remote repo
def 'git sync-branch' [
  localRef: string   # Local git branch/ref to push
  localOid: string   # Local git commit object id
  remoteRef: string  # Remote git branch/ref to push to
] {

  cd $env.JUST_INVOKE_DIR
  # `git hash-object --stdin < /dev/null` will raise "fatal: could not open '<' for reading: No such file or directory" error
  # 一定要 trim 啊，否则后面可能匹配不到，哎呦……
  let zero = (git hash-object -t tree /dev/null | str find-replace -a '[0-9a-f]' '0' | str trim)
  let destBranch = ($remoteRef | str find-replace 'refs/heads/' '')
  let localBranch = ($localRef | str find-replace 'refs/heads/' '')
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { $destBranch } else { 'i' })

  if (has-ref $'origin/($confBr)') == $false {
    $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit --now
  }
  let pushConf = (git show $'origin/($confBr):.termixrc' | from toml | to json)
  let ignored = (get-env SYNC_IGNORE_ALIAS '')
  # The following line not work: ^^^ Expected column path, found string
  # let matchBranch = ($pushConf | get branches | default $destBranch '' | select $destBranch | compact | length)
  # 获取待同步目的仓库及目的分支映射
  let dests = ($pushConf | query json $'branches.($destBranch)')
  # 如果没有任何同步配置直接退出
  # FIXME: ignore `error: Coercion error`
  do -i {
    if ($dests == $nothing) { exit --now }
  }

  let syncDests = ($dests | update SYNC {
      get repo | each { |it| if ($',($ignored),' =~ $',($it),') { '   x' } else { '   √' } }
    } | update source $localBranch | move source --before dest | sort-by SYNC)
  # 如果没有找到对应分支的 push hook 配置则直接退出
  if (($syncDests | length) > 0) {
    $'(char nl)Found the following matched dests from (ansi g)`origin/($confBr):.termixrc`(ansi reset):(char nl)'
    echo $syncDests | default lock '-' | move lock --before SYNC
  } else { exit --now }

  echo $syncDests | where SYNC == '   √' | each { |iter|
    let syncFrom = (get-sync-ref $localBranch $iter)
    let gitUrl = ($pushConf | query json $'repos.($iter.repo).git')
    let navUrl = ($pushConf | query json $'repos.($iter.repo).url')
    if $localOid == $zero {
      ^echo $'Remove remote branch (ansi p)($iter.dest) of repo ($iter.repo)(ansi reset) -->(char nl)'
      # You MUST use '--no-verify' to prevent infinit loops!!!
      git push --no-verify $gitUrl $':($iter.dest)'
    } else {
      if $syncFrom == $nothing {} else { do-sync $syncFrom $gitUrl $iter }
    }
    if ($navUrl != '' && $syncFrom != $nothing) { ^echo $'You can check the result from: (ansi g)($navUrl)(ansi reset)' }
  } | str collect
}
