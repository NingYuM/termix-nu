#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/05 13:55:20
# Usage:
#   t desc
#   t desc master

# Show branch description from branch description file `d` of `i` branch
export def main [
  branch: string        # The branch to query from description file
  --show-notes: any     # Set to 'true' to show notes information, defined as `any` acutually `bool`
] {

  let descFile = 'd.toml'
  let localIExists = has-ref i
  let remoteIExists = has-ref origin/i
  if ($localIExists or $remoteIExists) == false {
    $'You do not have an i branch, branch description query failed, bye...(char nl)'
    exit --now
  }
  # 本地 i 分支优先级高于远程
  let querySource = if ($localIExists) { 'i' } else { 'origin/i' }
  let descriptions = (git show $'($querySource):($descFile)' | from toml | to json)
  let queryBranch = if ($branch | is-empty) { (git branch --show-current | str trim) } else { $branch }
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = ($queryBranch | str replace -a '\.' '\.')
  let desc = ($descriptions | query json $'descriptions.($escapedBranch)')
  let rules = ($descriptions | query json 'rules')
  $'(char nl)(ansi p)($queryBranch) (ansi reset)分支描述：(char nl)'
  hr-line; $'(char nl)($desc)(char nl)'

  if ($show_notes) {
    $rules | each -n { |rule|
      echo $'(ansi g)($rule.index + 1)(ansi reset). ($rule.item)'
    } | str join $'(char nl)'; char nl
  }
}

# (localBranches + describedBranches)   hasDesc   remoteExist
