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

  cd $nu.env.JUST_INVOKE_DIR
  # 一定要 trim 啊，否则后面可能匹配不到，哎呦……
  let zero = (git hash-object --stdin < /dev/null | tr '[0-9a-f]' '0' | str trim)
  let useRef = (if $localOid == $zero { $remoteRef } { $localRef })
  let current = ($useRef | str find-replace 'refs/heads/' '')
  # Decide which branch to get `.termixrc` conf from ?
  let useConfBr = (get-conf useConfFromBranch)
  let confBr = (if $useConfBr == '_current_' { $current } { 'i' })

  if (has-ref $'origin/($confBr)') {} {
    $'Branch (ansi r)($confBr) does not exist in `origin` remote, ignore syncing(ansi reset)...(char nl)'
    exit --now
  }
  let pushConf = (git show $'origin/($confBr):.termixrc' | from toml | to json)
  let ignored = (get-env SYNC_IGNORE_ALIAS '')
  # The following line not work: ^^^ Expected column path, found string
  # let matchBranch = ($pushConf | get branches | default $current '' | select $current | compact | length)
  # 获取待同步目的仓库及目的分支映射
  let dests = ($pushConf | query json $'branches.($current)')
  # 如果没有任何同步配置直接退出
  # FIXME: ignore `error: Coercion error`
  do -i {
    if ($dests == $nothing) { exit --now } {}
  }

  let syncDests = ($dests | insert SYNC {
      get repo | each { if ($',($ignored),' =~ $',($it),') { '   x' } { '   √' } }
    } | insert source $current | move source --before dest | sort-by SYNC)
  # 如果没有找到对应分支的 push hook 配置则直接退出
  if (($syncDests | length) > 0) {
    $'(char nl)Found the following matched dests from (ansi g)`origin/($confBr):.termixrc`(ansi reset):(char nl)'
    echo $syncDests
  } { exit --now }

  echo $syncDests | where SYNC == '   √' | each {
    let gitUrl = ($pushConf | query json $'repos.($it.repo).git')
    let navUrl = ($pushConf | query json $'repos.($it.repo).url')
    if $localOid == $zero {
      ^echo $'Remove remote branch (ansi p)($it.dest) of repo ($it.repo)(ansi reset) -->(char nl)'
      # You MUST use '--no-verify' to prevent infinit loops!!!
      git push --no-verify $gitUrl $':($it.dest)'
    } {
      ^echo $'Sync from local (ansi g)($current)(ansi reset) to remote (ansi p)($it.dest) of repo ($it.repo)(ansi reset) -->(char nl)'
      let forcePush = (get-env FORCE_PUSH '0' | into int)
      if ($forcePush == 1) {
        # You MUST use '--no-verify' to prevent infinit loops!!!
        git push --no-verify --force $gitUrl $'($current):($it.dest)'
      } {
        git push --no-verify $gitUrl $'($current):($it.dest)'
      }
    }
    if ($navUrl != '') { ^echo $'You can check the result from: (ansi g)($navUrl)(ansi reset)\n' } { ^echo '' }
  }
  char nl
}
