#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/17 11:50:20
# Usage:
#   t check-branch

use ../utils/common.nu [ECODE, has-ref]

# Check whether all remote branches have related description
export def main [] {

  $env.config.table.mode = 'light'
  git fetch origin -p
  let descFile = 'd.toml'
  let localIExists = has-ref i
  let remoteIExists = has-ref origin/i

  if not ($localIExists or $remoteIExists) {
    print -e $'You do not have an i branch, branch description query failed, bye...(char nl)'
    exit $ECODE.MISSING_DEPENDENCY
  }

  git fetch origin i:i -q   # 更新远程 i 分支到本地
  # 本地 i 分支优先级高于远程
  let repo = ($env.PWD | path basename | str trim)
  let querySource = if $localIExists { 'i' } else { 'origin/i' }
  let descriptions = (git show $'($querySource):($descFile)' | from toml | to json)
  # Alternatively since nushell v0.40.0 you can use the following line, which is longer but more readable
  # git ls-remote --heads --refs origin | detect columns -n | rename cid name |
  #     update name { get name | str replace 'refs/heads/' '' } | get name
  let remoteBranches = (git ls-remote --heads --refs origin | lines | par-each -k { str substring 52.. })
  let allDescribed = ($remoteBranches | where (no-desc $descriptions $it) | str join | str trim | is-empty)

  if ($allDescribed) {
    print $'(char nl) Well done! All Branches have been described in (ansi g)($repo)(ansi reset).(char nl)(char nl)'
  } else {
    print $'(ansi p)(char nl)  Branches that do not have a description in (ansi g)($repo)(ansi reset): (char nl)(ansi reset)'
    print ($remoteBranches
      | where (no-desc $descriptions $it)
      | wrap name
      | upsert commit-by { |it| git show $'origin/($it.name)' -s --format='%an' | str trim }
      | upsert last-commit { |it| git show $'origin/($it.name)' --no-patch --format=%ci | into datetime }
      | sort-by last-commit)
  }

  # 检查并显示所有描述存在但是远程已经被删掉的分支
  let gone = (
    $descriptions
      | query json 'descriptions'
      | transpose name description
      | get name
      | par-each -k { |br| if not (has-ref origin/($br)) { $br } }
      | compact
  )

  if ($gone | length) > 0 {
    print $'(ansi p)(char nl)  Branches that have a description but were(ansi r) removed from remote(ansi reset):(char nl)(ansi reset)'
    print ($gone | wrap 'name')
  }

  let syncConf = (git show $'($querySource):.termixrc' | from toml | to json)
  # 获取待同步目的仓库及目的分支映射
  let syncs = ($syncConf | query json $'branches')
  # 检查并显示所有有同步配置但是远程已经被删掉的分支
  let gone = (
    $syncs
      | transpose name sync
      | insert status { |br| if (has-ref origin/($br.name)) { true } else { 'Remote Removed' } }
      | where status != true
      | reject sync
  )
  if ($gone | length) > 0 {
    print $'(ansi p)(char nl)  Branches that have sync configs but were(ansi r) removed from remote(ansi reset):(char nl)(ansi reset)'
    print $gone
  }

}

# Check if the specified branch has a description in `descriptions`
def no-desc [
  descriptions: string,
  branch: string,
] {
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = ($branch | str replace -a '.' '\.')
  # ($descriptions | select $escapedBranch | compact | length) == 0
  let noDescription = ($descriptions | query json $'descriptions.($escapedBranch)' | is-empty)
  ($noDescription and $branch != 'i')
}
