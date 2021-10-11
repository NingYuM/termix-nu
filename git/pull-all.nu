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
  let startMark = $'[($alias)/'
  let behindMark = ': behind'
  let currentBranch = (git branch --show-current)
  # Save changes before switch to other branches
  let statusCheck = (git status --porcelain)
  if ($statusCheck | empty?) {} {
    git stash save 'Stash before running pull-all action'
  }
  # `LANG=en_US git` 强制 git 输出语言切换为英文
  LANG=en_US git branch -vv |
    lines |
    each {
      let isBehind = ($it | str contains $behindMark)
      if $isBehind {
        let endIdx = ($it | str index-of $behindMark)
        let startIdx = (($it | str index-of $startMark) + ($startMark | str length))
        let branchName = ($it | str substring $'($startIdx),($endIdx)')
        echo $it
        $'(char nl)  (ansi gb)--> Start to update branch: ($branchName)(ansi reset)(char nl)'
        git checkout $branchName; git pull
      } {}
    }
  git checkout $currentBranch
  if ($statusCheck | empty?) {} { git stash pop }
}
