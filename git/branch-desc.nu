#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/11/05 13:55:20
# Usage:
#   t desc
#   t desc master

use ../utils/common.nu [ECODE, has-ref, hr-line]

# Show branch description from branch description file `d` of `i` branch
export def main [
  branch?: string,       # The branch to query from description file
  --all(-a),             # Show all branches' description
  --show-notes(-n),      # Show notes information
] {

  let descFile = 'd.toml'
  let localIExists = has-ref i
  let remoteIExists = has-ref origin/i
  if not ($localIExists or $remoteIExists) {
    print $'You do not have an (ansi r)i(ansi reset) branch, branch description query failed, bye...(char nl)'
    exit $ECODE.MISSING_DEPENDENCY
  }

  git fetch origin i:i -q   # 更新远程 i 分支到本地
  # 本地 i 分支优先级高于远程
  let querySource = if ($localIExists) { 'i' } else { 'origin/i' }
  let descriptions = (git show $'($querySource):($descFile)' | from toml)
  if $all {
    print $'(char nl)分支描述：'; hr-line
    $descriptions.descriptions | print; exit $ECODE.SUCCESS
  }

  let queryBranch = if ($branch | is-empty) { (git branch --show-current | str trim) } else { $branch }
  let desc = $descriptions | get descriptions? | get -i $queryBranch
  print $'(char nl)(ansi p)($queryBranch) (ansi reset)分支描述：(char nl)'
  hr-line
  print $'(char nl)($desc | default $"(ansi grey66)-- No Description --(ansi reset)")(char nl)'

  if ($show_notes) {
    $descriptions.rules | enumerate | each {|rule|
      print $'(ansi g)($rule.index + 1 | fill --alignment right -w 2)(ansi reset). ($rule.item)'
    } | str join (char nl)
  }
}

# (localBranches + describedBranches)   hasDesc   remoteExist
