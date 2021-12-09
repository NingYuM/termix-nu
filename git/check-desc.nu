# Author: hustcer
# Created: 2021/11/17 11:50:20
# Usage:
#   t check-desc

# Check whether all remote branches have related description
def 'check-desc' [] {

  git fetch origin -p
  let descFile = 'd.toml'
  let localIExists = (has-ref i)
  let remoteIExists = (has-ref origin/i)
  if ($localIExists || $remoteIExists) {} {
    $'You do not have an i branch, branch description query failed, bye...(char nl)'
    exit --now
  }
  # 本地 i 分支优先级高于远程
  let querySource = (if ($localIExists) { 'i' } { 'origin/i' })
  let descriptions = (git show $'($querySource):($descFile)' | from toml | to json)
  # Alternatively since nushell v0.40.0 you can use the following line, which is longer but more readable
  # git ls-remote --heads --refs origin | detect columns -n | rename cid name |
  #     update name { get name | str find-replace 'refs/heads/' '' } | get name
  let remoteBranches = (git ls-remote --heads --refs origin | lines | str substring '52,')
  let repo = (pwd | path basename)

  $'(ansi p)(char nl)  Branches that do not have a description in (ansi g)($repo)(ansi reset):(char nl)(char nl)(ansi reset)'
  $remoteBranches | where (no-desc $descriptions $it) | wrap name |
    insert commit-by {
      get name | each { git show $'origin/($it)' -s --format='%an' }
    } |
    insert last-commit {
      get name |
      each { git show $'origin/($it)' --no-patch --format=%ci | str to-datetime }
    } |
    sort-by last-commit

  # 检查并显示所有描述存在但是远程已经被删掉的分支
  let gone = ($descriptions | query json 'descriptions' | pivot | rename name description | get name |
              each { |br| if (has-ref $'origin/($br)') == $false { $br } { '' } })

  # FIXME: 有点Hack啊，如果不通过这种方式判断就会有各种错……😌
  let empty = ($gone | str collect | str trim | empty?)
  if ($empty) {} {
    $'(ansi p)  Branches that have a description but were(ansi r) removed from remote(ansi reset):(char nl)(char nl)(ansi reset)'
    $gone | compact | wrap 'name'
  }

}

# Check if the specified branch has a description in `descriptions`
def 'no-desc' [
  descriptions: string
  branch: string
] {
  # 处理分支名称包含‘.’的情况: `support/release-2.4`
  let escapedBranch = ($branch | str find-replace -a '\.' '\.')
  # ($descriptions | select ($escapedBranch | into column_path) | compact | length) == 0
  let noDescription = ($descriptions | query json $'descriptions.($escapedBranch)') == ''
  echo ($noDescription && $branch != 'i')
}
