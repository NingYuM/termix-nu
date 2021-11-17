# Author: hustcer
# Created: 2021/11/17 11:50:20
# Usage:
#   t check-desc

# Check whether all remote branches have related description
def 'check-desc' [] {

  let descFile = 'd.json'
  let localIExists = (has-ref i)
  let remoteIExists = (has-ref origin/i)
  if ($localIExists || $remoteIExists) {} {
    $'You do not have a i branch, branch description query failed, bye...(char nl)'
    exit --now
  }
  # 本地 i 分支优先级高于远程
  let querySource = (if ($localIExists) { 'i' } { 'origin/i' })
  let descriptions = (git show $'($querySource):($descFile)')
  let remoteBranches = (git ls-remote --heads --refs origin | lines | str substring '52,')
  let repo = (pwd | path basename)

  $'(ansi p)(char nl)  Branches that do not have a description in (ansi g)($repo)(ansi reset):(char nl)(char nl)(ansi reset)'
  $remoteBranches | where (no-desc $descriptions $it) | wrap BranchName
}

# Check if the specified branch has a description in `descriptions`
def 'no-desc' [
  descriptions: any
  branch: string
] {
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = ($branch | str find-replace -a '\.' '\.')
  # ($descriptions | select ($escapedBranch | into column_path) | compact | length) == 0
  let noDescription = ($descriptions | query json $'descriptions.($escapedBranch)') == ''
  echo ($noDescription && $branch != 'i')
}
