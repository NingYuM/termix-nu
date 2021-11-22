# Author: hustcer
# Created: 2021/11/05 13:55:20
# Usage:
#   t desc
#   t desc master

# Show branch description from branch description file `d` of `i` branch
def 'branch-desc' [
  branch?: string       # The branch to query from description file
  --show-notes: string  # Set to 'ture' to show notes infomation
] {

  let descFile = 'd.toml'
  let localIExists = (has-ref i)
  let remoteIExists = (has-ref origin/i)
  if ($localIExists || $remoteIExists) {} {
    $'You do not have a i branch, branch description query failed, bye...(char nl)'
    exit --now
  }
  # 本地 i 分支优先级高于远程
  let querySource = (if ($localIExists) { 'i' } { 'origin/i' })
  let descriptions = (git show $'($querySource):($descFile)' | from toml | to json)
  let queryBranch = (if ($branch | empty?) { (git branch --show-current) } { $branch })
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = ($queryBranch | str find-replace -a '\.' '\.')
  let desc = ($descriptions | query json $'descriptions.($escapedBranch)')
  let rules = ($descriptions | query json 'rules')
  $'(char nl)(ansi p)($queryBranch) (ansi reset)分支描述：'
  $'(char nl)(ansi g)---------------------------------------------------------------------------(ansi reset)'
  $'(char nl)($desc)(char nl)(char nl)'
  if ($show-notes == 'false') {} {
    $rules | each -n { |rule|
      echo $'(ansi g)($rule.index + 1)(ansi reset). ($rule.item)'
    } | str collect $'(char nl)'; char nl
  }
}

# (localBranches + describedBranches)   hasDesc   remoteExist
