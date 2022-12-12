#!/usr/bin/env nu
# Author: hustcer
# Created: 2021/09/13 11:06:52
# Usage:
#   t pull-all

# Pull all local branches from remote repo
export def 'git pull-all' [
  repoDir: string   # The git repo dir to run pull action
  alias: string     # The remote url alias for git repo
] {

  cd $repoDir
  let currentBranch = (git branch --show-current | str trim)
  # Save changes before switch to other branches
  let statusCheck = git status --porcelain
  if ($statusCheck | is-empty) == false {
    git stash save 'Stash before running pull-all action'
  }

  git fetch $alias -p
  let available = (git branch | into string | lines | str substring '2,')
  # `LANG=en_US git` 强制 git 输出语言切换为英文
  let ahead = (LANG=en_US git branch -vv | lines | find ': ahead')
  let behind = (LANG=en_US git branch -vv | lines | find ': behind')
  $available | each { |br|
    let pattern = $'($alias)/($br):'
    if ($behind | find -r $pattern | length) > 0 or ($ahead | find -r $pattern | length) > 0 {
      git checkout $br
      let stat = gstat
      # Just pull if local repo is behind remote
      if ($stat.behind > 0 and $stat.ahead == 0) {
        print $'(ansi p)Start pulling ($br) branch...(ansi reset)'
        git pull; hr-line
      }
      # If local is behind remote and have commits at the same time, do a reset, may be DANGEROUS
      if ($stat.behind > 0 and $stat.ahead > 0) {
        print $'(ansi p)Start reseting ($alias)/($br) branch...(ansi reset)'
        git reset --hard $'($alias)/($br)'; hr-line
      }
    }
  }
  git checkout $currentBranch
  if ($statusCheck | is-empty) == false { git stash pop }
}
