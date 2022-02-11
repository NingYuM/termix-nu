# Author: hustcer
# Created: 2021/09/13 11:06:52
# Usage:
#   t pull-all

# Pull all local branches from remote repo
def 'git pull-all' [
  repoDir: string   # The git repo dir to run pull action
  alias: string     # The remote url alias for git repo
] {

  cd $repoDir
  let currentBranch = (git branch --show-current | str trim)
  # Save changes before switch to other branches
  let statusCheck = (git status --porcelain)
  if ($statusCheck | empty?) == $false {
    git stash save 'Stash before running pull-all action'
  }

  git fetch $alias -p
  let available = (git branch | into string | lines | str substring (2,))
  # FIXME: `LANG=en_US git` 强制 git 输出语言切换为英文
  let ahead = (git br -vv | lines | find ': ahead')
  let behind = (git br -vv | lines | find ': behind')
  $available | each { |br|
    if ($behind | find $br | length) > 0 || ($ahead | find $br | length) > 0 {
      git checkout $br
      let stat = (gstat)
      if ($stat.behind > 0 && $stat.ahead == 0) { git pull }
      if ($stat.behind > 0 && $stat.ahead > 0) { git reset --hard $'($alias)/($br)' }
    }
  } | str collect
  git checkout $currentBranch
  if ($statusCheck | empty?) == $false { git stash pop }
}
